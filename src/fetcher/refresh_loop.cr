require "gc"
require "time"
require "atomic"
require "../config"
require "../models"
require "../storage"
require "../health_monitor"
require "../services/clustering_service"
require "../software_fetcher"
require "./feed_fetcher"

CLUSTERING_JOBS = Atomic(Int32).new(0)

def refresh_all(config : Config)
  STATE.config_title = config.page_title
  STATE.config = config

  all_configs = {} of String => Feed
  config.feeds.each { |feed| all_configs[feed.url] = feed }
  config.tabs.each { |tab| tab.feeds.each { |feed| all_configs[feed.url] = feed } }

  STDERR.puts "[#{Time.local}] refresh_all: starting - #{all_configs.size} feeds to fetch"

  existing_data = (STATE.feeds + STATE.tabs.flat_map(&.feeds)).index_by(&.url)
  STDERR.puts "[#{Time.local}] refresh_all: existing_data.size=#{existing_data.size}"

  channel = Channel(FeedData).new
  all_configs.each_value do |feed|
    spawn do
      SEM.receive
      begin
        prev = existing_data[feed.url]?
        channel.send(fetch_feed(feed, config.item_limit, config.db_fetch_limit, prev))
      ensure
        SEM.send(nil)
      end
    end
  end

  fetched_map = {} of String => FeedData
  success_count = 0
  all_configs.size.times do
    data = channel.receive
    if data && !data.items.empty?
      fetched_map[data.url] = data
      success_count += 1
    else
      STDERR.puts "[#{Time.local}] refresh_all: failed to fetch #{data ? data.url : "unknown"}"
    end
  end

  STDERR.puts "[#{Time.local}] refresh_all: fetched #{fetched_map.size}/#{all_configs.size} feeds successfully"

  STDERR.puts "[#{Time.local}] refresh_all: updating STATE (feeds=#{STATE.feeds.size}, tabs=#{STATE.tabs.size})"

  STATE.with_lock do
    STATE.feeds.clear
    STATE.tabs.each &.feeds.clear
    STATE.software_releases.clear

    STATE.feeds = config.feeds.map { |feed| fetched_map[feed.url] || error_feed_data(feed, "Failed to fetch") }
    STDERR.puts "[#{Time.local}] refresh_all: STATE.feeds=#{STATE.feeds.size}"
    STATE.software_releases = [] of FeedData
    if sw = config.software_releases
      if sw_box = fetch_sw_with_config(sw, config.item_limit)
        STATE.software_releases << sw_box
      end
    end

    STATE.tabs = config.tabs.map do |tab_config|
      tab = Tab.new(tab_config.name)
      tab.feeds = tab_config.feeds.map { |feed| fetched_map[feed.url] || error_feed_data(feed, "Failed to fetch") }
      STDERR.puts "[#{Time.local}] refresh_all: tab '#{tab.name}' has #{tab.feeds.size} feeds"
      if sw = tab_config.software_releases
        if sw_box = fetch_sw_with_config(sw, config.item_limit)
          tab.software_releases = [sw_box]
        end
      end
      tab
    end

    STATE.updated_at = Time.local
  end

  async_clustering(fetched_map.values.to_a)

  GC.collect

  STDERR.puts "[#{Time.local}] refresh_all: complete - STATE.feeds=#{STATE.feeds.size}, STATE.tabs=#{STATE.tabs.size}"
end

def async_clustering(feeds : Array(FeedData))
  clustering_channel = Channel(Nil).new(10)

  STATE.is_clustering = true
  CLUSTERING_JOBS.set(feeds.size)

  spawn do
    feeds.each do |feed_data|
      spawn do
        clustering_channel.send(nil)
        begin
          process_feed_item_clustering(feed_data)
        ensure
          clustering_channel.receive
          if CLUSTERING_JOBS.sub(1) <= 1
            STATE.is_clustering = false
          end
        end
      end
    end
  end
end

def compute_cluster_for_item(item_id : Int64, title : String, item_feed_id : Int64? = nil) : Int64?
  cache = FeedCache.instance
  service = clustering_service
  service.compute_cluster_for_item(item_id, title, cache, item_feed_id)
end

def process_feed_item_clustering(feed_data : FeedData) : Nil
  return if feed_data.items.empty?

  cache = FeedCache.instance

  feed_id = cache.get_feed_id(feed_data.url)

  feed_data.items.each do |item|
    item_id = cache.get_item_id(feed_data.url, item.link)

    next unless item_id

    compute_cluster_for_item(item_id, item.title, feed_id)
  end
end

def start_refresh_loop(config_path : String)
  active_config = load_config(config_path)
  last_mtime = File.info(config_path).modification_time

  save_feed_cache(FeedCache.instance, active_config.cache_retention_hours, active_config.max_cache_size_mb)

  spawn do
    loop do
      refresh_start_time = Time.monotonic

      begin
        current_mtime = File.info(config_path).modification_time

        if current_mtime > last_mtime
          new_config = load_config(config_path)
          active_config = new_config
          last_mtime = current_mtime

          puts "[#{Time.local}] Config change detected. Reloaded feeds.yml"
          refresh_all(active_config)
          puts "[#{Time.local}] Refreshed after config change"
        else
          refresh_all(active_config)
          puts "[#{Time.local}] Refreshed feeds and ran GC"
        end

        save_feed_cache(FeedCache.instance, active_config.cache_retention_hours, active_config.max_cache_size_mb)

        refresh_duration = (Time.monotonic - refresh_start_time).total_seconds
        if refresh_duration > (active_config.refresh_minutes * 60) * 2
          HealthMonitor.log_warning("Refresh took #{refresh_duration.round(2)}s (expected #{active_config.refresh_minutes * 60}s) - possible hang detected")
        end

        sleep (active_config.refresh_minutes * 60).seconds
      rescue ex
        HealthMonitor.log_error("refresh_loop", ex)
        sleep 1.minute
      end
    end
  end
end

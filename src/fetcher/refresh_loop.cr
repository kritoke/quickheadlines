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
  StateStore.update(&.copy_with(refreshing: true))
  StateStore.update(&.copy_with(config_title: config.page_title, config: config))

  all_configs = {} of String => Feed
  config.feeds.each { |feed| all_configs[feed.url] = feed }
  config.tabs.each { |tab| tab.feeds.each { |feed| all_configs[feed.url] = feed } }

  STDERR.puts "[#{Time.local}] refresh_all: starting - #{all_configs.size} feeds to fetch"

  existing_data = (StateStore.feeds + StateStore.tabs.flat_map(&.feeds)).index_by(&.url)
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

  STDERR.puts "[#{Time.local}] refresh_all: building new state (feeds=#{fetched_map.size}, tabs=#{config.tabs.size})"

  # Build new state immutably
  new_feeds = config.feeds.map { |feed| fetched_map[feed.url]? || error_feed_data(feed, "Failed to fetch") }

  new_software_releases = [] of FeedData
  if sw = config.software_releases
    if sw_box = fetch_sw_with_config(sw, config.item_limit)
      new_software_releases = [sw_box]
    end
  end

  new_tabs = config.tabs.map do |tab_config|
    tab_feeds = tab_config.feeds.map { |feed| fetched_map[feed.url]? || error_feed_data(feed, "Failed to fetch") }
    tab_releases = [] of FeedData
    if sw = tab_config.software_releases
      if sw_box = fetch_sw_with_config(sw, config.item_limit)
        tab_releases = [sw_box]
      end
    end
    Tab.new(tab_config.name, tab_feeds, tab_releases)
  end

  # Atomic state update - no mutations
  StateStore.update do |state|
    state.copy_with(
      feeds: new_feeds,
      software_releases: new_software_releases,
      tabs: new_tabs,
      updated_at: Time.local
    )
  end

  STDERR.puts "[#{Time.local}] refresh_all: STATE updated - feeds=#{new_feeds.size}, tabs=#{new_tabs.size}"

  # Ensure feeds are persisted to database before clustering runs
  # This prevents KeyError on fresh deployments when feeds aren't in DB yet
  async_clustering(fetched_map.values.to_a)

  GC.collect

  STDERR.puts "[#{Time.local}] refresh_all: complete - STATE.feeds=#{new_feeds.size}, STATE.tabs=#{new_tabs.size}"
end

def async_clustering(feeds : Array(FeedData))
  return if feeds.empty?

  clustering_channel = Channel(Nil).new(10)

  StateStore.update(&.copy_with(clustering: true))
  CLUSTERING_JOBS.set(feeds.size)

  spawn do
    feeds.each do |feed_data|
      spawn do
        clustering_channel.send(nil)
        begin
          process_feed_item_clustering(feed_data)
        rescue ex
          STDERR.puts "[#{Time.local}] async_clustering: error processing #{feed_data.url}: #{ex.message}"
        ensure
          clustering_channel.receive
          if CLUSTERING_JOBS.sub(1) <= 1
            StateStore.update(&.copy_with(clustering: false))
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
  return unless feed_id

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

  # Skip initial refresh - cache was already loaded before server started
  # This allows fast startup, refresh happens after first interval
  first_run = true

  spawn do
    loop do
      refresh_start_time = Time.monotonic

      begin
        # Always run refresh on first iteration to pick up any new feeds
        if first_run
          first_run = false
          STDERR.puts "[#{Time.local}] Running initial refresh to fetch feeds"
          refresh_all(active_config)
          puts "[#{Time.local}] Initial refresh complete"
        else
          current_mtime = File.info(config_path).modification_time

          if current_mtime > last_mtime
            new_config = load_config(config_path)
            active_config = new_config
            last_mtime = current_mtime

            puts "[#{Time.local}] Config change detected. Reloaded feeds.yml"
            refresh_all(active_config)
            puts "[#{Time.local}] Refreshed after config change"
            sleep (active_config.refresh_minutes * 60).seconds
            next
          else
            refresh_all(active_config)
            puts "[#{Time.local}] Refreshed feeds and ran GC"
          end
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

require "gc"
require "time"
require "atomic"
require "../config"
require "../models"
require "../storage"
require "../health_monitor"
require "../services/clustering_service"
require "../software_fetcher"
require "../websocket"
require "./feed_fetcher"

MAX_PARALLEL_CLUSTERING = 20
REFRESH_MUTEX           = Mutex.new
REFRESH_IN_PROGRESS     = Atomic(Bool).new(false)

private def collect_feed_configs(config : Config) : Hash(String, Feed)
  all_configs = {} of String => Feed
  config.feeds.each { |feed| all_configs[feed.url] = feed }
  config.tabs.each { |tab| tab.feeds.each { |feed| all_configs[feed.url] = feed } }
  all_configs
end

private def fetch_feeds_concurrently(all_configs : Hash(String, Feed), existing_data : Hash(String, FeedData), config : Config) : Hash(String, FeedData)
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
  all_configs.size.times do
    data = channel.receive
    if data && !data.items.empty?
      fetched_map[data.url] = data
    elsif config.debug?
      Log.for("quickheadlines.feed").warn { "refresh_all: failed to fetch #{data ? data.url : "unknown"}" }
    end
  end
  fetched_map
end

private def build_software_releases(sw_config : SoftwareConfig?, item_limit : Int32) : Array(FeedData)
  return [] of FeedData unless sw_config
  if sw_box = fetch_sw_with_config(sw_config, item_limit)
    [sw_box]
  else
    [] of FeedData
  end
end

private def build_tab_feeds(tab_config : TabConfig, fetched_map : Hash(String, FeedData), item_limit : Int32) : Tab
  tab_feeds = tab_config.feeds.map { |feed| fetched_map[feed.url]? || error_feed_data(feed, "Failed to fetch") }
  tab_releases = build_software_releases(tab_config.software_releases, item_limit)
  Tab.new(tab_config.name, tab_feeds, tab_releases)
end

def refresh_all(config : Config)
  refresh_all(config, FeedCache.instance, DatabaseService.instance)
end

def refresh_all(config : Config, cache : FeedCache, db_service : DatabaseService)
  StateStore.update(&.copy_with(refreshing: true))
  StateStore.update(&.copy_with(config_title: config.page_title, config: config))

  all_configs = collect_feed_configs(config)

  if config.debug?
    Log.for("quickheadlines.feed").debug { "refresh_all: starting - #{all_configs.size} feeds to fetch" }
  end

  existing_data = (StateStore.feeds + StateStore.tabs.flat_map(&.feeds)).index_by(&.url)
  if config.debug?
    Log.for("quickheadlines.feed").debug { "refresh_all: existing_data.size=#{existing_data.size}" }
  end

  fetched_map = fetch_feeds_concurrently(all_configs, existing_data, config)

  if config.debug?
    Log.for("quickheadlines.feed").debug { "refresh_all: fetched #{fetched_map.size}/#{all_configs.size} feeds successfully" }
    Log.for("quickheadlines.feed").debug { "refresh_all: building new state (feeds=#{fetched_map.size}, tabs=#{config.tabs.size})" }
  end

  # Build new state immutably
  new_feeds = config.feeds.map { |feed| fetched_map[feed.url]? || error_feed_data(feed, "Failed to fetch") }
  new_tabs = config.tabs.map { |tab_config| build_tab_feeds(tab_config, fetched_map, config.item_limit) }
  new_software_releases = build_software_releases(config.software_releases, config.item_limit)

  # Atomic state update - no mutations
  StateStore.update do |state|
    state.copy_with(
      feeds: new_feeds,
      software_releases: new_software_releases,
      tabs: new_tabs,
      updated_at: Time.utc
    )
  end

  # Broadcast update to WebSocket clients
  EventBroadcaster.notify_feed_update(StateStore.updated_at.to_unix_ms)

  if config.debug?
    Log.for("quickheadlines.feed").debug { "refresh_all: STATE updated - feeds=#{new_feeds.size}, tabs=#{new_tabs.size}" }
  end

  # Ensure feeds are persisted to database before clustering runs
  # This prevents KeyError on fresh deployments when feeds aren't in DB yet
  async_clustering(fetched_map.values.to_a, cache, db_service)

  GC.collect

  if config.debug?
    Log.for("quickheadlines.feed").debug { "refresh_all: complete - StateStore.feeds=#{new_feeds.size}, StateStore.tabs=#{new_tabs.size}" }
  end
end

def async_clustering(feeds : Array(FeedData), cache : FeedCache, db_service : DatabaseService)
  return if feeds.empty?

  semaphore = Channel(Nil).new(MAX_PARALLEL_CLUSTERING)
  MAX_PARALLEL_CLUSTERING.times { semaphore.send(nil) }

  completion_channel = Channel(Nil).new(feeds.size)

  StateStore.update(&.copy_with(clustering: true))

  spawn do
    feeds.each do |feed_data|
      spawn do
        semaphore.receive
        begin
          process_feed_item_clustering(feed_data, cache, db_service)
        rescue ex
          Log.for("quickheadlines.clustering").error(exception: ex) { "async_clustering: error processing #{feed_data.url}" }
        ensure
          semaphore.send(nil)
          completion_channel.send(nil)
        end
      end
    end
  end

  spawn do
    feeds.size.times { completion_channel.receive }
    StateStore.update(&.copy_with(clustering: false))
  end
end

def compute_cluster_for_item(item_id : Int64, title : String, cache : FeedCache, db_service : DatabaseService, item_feed_id : Int64? = nil) : Int64?
  service = clustering_service(db_service)
  service.compute_cluster_for_item(item_id, title, cache, item_feed_id)
end

def process_feed_item_clustering(feed_data : FeedData, cache : FeedCache, db_service : DatabaseService) : Nil
  return if feed_data.items.empty?

  feed_id = cache.get_feed_id(feed_data.url)
  return unless feed_id

  feed_data.items.each do |item|
    item_id = cache.get_item_id(feed_data.url, item.link)

    next unless item_id

    compute_cluster_for_item(item_id, item.title, cache, db_service, feed_id)
  end
end

def start_refresh_loop(config_path : String, cache : FeedCache, db_service : DatabaseService)
  active_config = load_config(config_path)
  last_mtime = File.info(config_path).modification_time

  save_feed_cache(cache, active_config.cache_retention_hours, active_config.max_cache_size_mb)

  first_run = true

  spawn do
    loop do
      refresh_start_time = Time.monotonic

      begin
        if REFRESH_IN_PROGRESS.swap(true)
          Log.for("quickheadlines.feed").warn { "Refresh already in progress, skipping this cycle" }
          sleep (active_config.refresh_minutes * 60).seconds
          next
        end

        begin
          if first_run
            first_run = false
            if active_config.debug?
              Log.for("quickheadlines.feed").debug { "Running initial refresh to fetch feeds" }
            end
            refresh_all(active_config, cache, db_service)
            if active_config.debug?
              Log.for("quickheadlines.feed").debug { "Initial refresh complete" }
            end
          else
            current_mtime = File.info(config_path).modification_time

            if current_mtime > last_mtime
              new_config = load_config(config_path)
              active_config = new_config
              last_mtime = current_mtime

              if active_config.debug?
                Log.for("quickheadlines.feed").debug { "Config change detected. Reloaded feeds.yml" }
              end
              refresh_all(active_config, cache, db_service)
              if active_config.debug?
                Log.for("quickheadlines.feed").debug { "Refreshed after config change" }
              end
              sleep (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE).seconds
              next
            else
              refresh_all(active_config, cache, db_service)
              if active_config.debug?
                Log.for("quickheadlines.feed").debug { "Refreshed feeds and ran GC" }
              end
            end
          end

          save_feed_cache(cache, active_config.cache_retention_hours, active_config.max_cache_size_mb)

          refresh_duration = (Time.monotonic - refresh_start_time).total_seconds
          if refresh_duration > (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE) * 2
            HealthMonitor.log_warning("Refresh took #{refresh_duration.round(2)}s (expected #{active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE}s) - possible hang detected")
          end

          sleep (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE).seconds
        ensure
          REFRESH_IN_PROGRESS.set(false)
        end
      rescue ex
        HealthMonitor.log_error("refresh_loop", ex)
        REFRESH_IN_PROGRESS.set(false)
        sleep 1.minute
      end
    end
  end
end

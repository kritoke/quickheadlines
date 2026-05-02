require "gc"
require "time"
require "../config"
require "../models"
require "../storage"
require "../software_fetcher"
require "../websocket"
require "./feed_fetcher"
require "./software_util"

module GCCollector
  @@last_gc_collect = Time.utc

  def self.trigger_if_needed : Nil
    now = Time.utc
    if now - @@last_gc_collect >= 5.minutes
      GC.collect
      @@last_gc_collect = now
      Log.for("quickheadlines.gc").debug { "Triggered GC.collect to release memory" }
    end
  end
end

private def trigger_gc_collection : Nil
  GCCollector.trigger_if_needed
end

private def check_semaphore_health
  expected = QuickHeadlines::Constants::CONCURRENCY
  available = 0
  # Use receive? (non-blocking) instead of select+timeout to avoid
  # Pairing Heap tree corruption from rapid timer create/destroy cycles.
  # Each call to select+timeout creates a libevent timer; rapid retries on
  # exception handlers cause the heap to become inconsistent.
  expected.times do
    if (permit = CONCURRENCY_SEMAPHORE.receive?).nil?
      break
    end
    available += 1
  end

  if available != expected
    Log.for("quickheadlines.feed").warn { "Semaphore health check: only #{available}/#{expected} slots available - refilling #{expected - available}" }
  end

  # Only send back exactly what was drained — not the full `expected` count.
  available.times { CONCURRENCY_SEMAPHORE.send(nil) }
end

private def collect_feed_configs(config : Config) : Hash(String, Feed)
  all_configs = {} of String => Feed
  config.feeds.each { |feed| all_configs[feed.url] = feed }
  config.tabs.each { |tab| tab.feeds.each { |feed| all_configs[feed.url] = feed } }
  all_configs
end

private def fetch_feeds_concurrently(all_configs : Hash(String, Feed), existing_data : Hash(String, FeedData), config : Config) : Hash(String, FeedData)
  channel = Channel(FeedData?).new
  all_configs.each_value do |feed|
    spawn do
      CONCURRENCY_SEMAPHORE.receive
      begin
        prev = existing_data[feed.url]?
        channel.send(FeedFetcher.instance.fetch(feed, config.item_limit, config.db_fetch_limit, prev))
      rescue ex
        Log.for("quickheadlines.feed").error(exception: ex) { "fetch_feeds_concurrently: error fetching #{feed.url}" }
        channel.send(nil)
      ensure
        CONCURRENCY_SEMAPHORE.send(nil)
      end
    end
    Fiber.yield
  end

  fetched_map = {} of String => FeedData
  completed = 0
  timeout_span = QuickHeadlines::Constants::FEED_FETCH_TIMEOUT_SECONDS.seconds
  fetch_start = Time.monotonic

  all_configs.size.times do
    Fiber.yield
    # Use non-blocking receive? instead of select+timeout to avoid
    # Pairing Heap tree corruption from rapid timer create/destroy cycles.
    if data = channel.receive?
      if data
        fetched_map[data.url] = data
      elsif config.debug?
        Log.for("quickheadlines.feed").warn { "refresh_all: failed to fetch feed" }
      end
      completed += 1
    end

    # Wall-clock timeout check after each iteration.
    elapsed = Time.monotonic - fetch_start
    if elapsed > timeout_span
      Log.for("quickheadlines.feed").warn { "fetch_feeds_concurrently: timed out after #{completed}/#{all_configs.size} feeds" }
      break
    end
  end
  fetched_map
end

private def build_software_releases(software_config : SoftwareConfig?, item_limit : Int32) : Array(FeedData)
  QuickHeadlines::SoftwareUtil.build_software_releases(software_config, item_limit)
end

private def build_tab_feeds(tab_config : TabConfig, fetched_map : Hash(String, FeedData), item_limit : Int32) : Tab
  tab_feeds = tab_config.feeds.map { |feed| fetched_map[feed.url]? || FeedFetcher.instance.build_error_feed(feed, "Failed to fetch") }
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

  new_feeds = config.feeds.map { |feed| fetched_map[feed.url]? || FeedFetcher.instance.build_error_feed(feed, "Failed to fetch") }
  new_tabs = config.tabs.map { |tab_config| build_tab_feeds(tab_config, fetched_map, config.item_limit) }

  StateStore.update do |state|
    state.copy_with(
      feeds: new_feeds,
      tabs: new_tabs,
      updated_at: Time.utc,
      refreshing: false
    )
  end

  EventBroadcaster.notify_feed_update(StateStore.updated_at.to_unix_ms)

  if config.debug?
    Log.for("quickheadlines.feed").debug { "refresh_all: complete - StateStore.feeds=#{new_feeds.size}, StateStore.tabs=#{new_tabs.size}" }
  end
end

def start_refresh_loop(config_path : String, cache : FeedCache, db_service : DatabaseService)
  load_result = load_validated_config(config_path)
  unless load_result.success && (initial_config = load_result.config)
    Log.for("quickheadlines.feed").error { "Failed to load config: #{load_result.error_message}" }
    return
  end
  active_config = initial_config
  last_mtime = File.info(config_path).modification_time

  save_feed_cache(cache, active_config.cache_retention_hours, active_config.max_cache_size_mb)

  first_run = true
  cycle_count = 0
  heartbeat_interval = 10

  spawn do
    loop do
      refresh_start_time = Time.utc

      if StateStore.refreshing?
        Log.for("quickheadlines.feed").warn { "Refresh already in progress, skipping this cycle" }
        sleep (active_config.refresh_minutes * 60).seconds
        break if QuickHeadlines.shutting_down?
        next
      end

      check_semaphore_health

      begin
        if first_run
          first_run = false
          if active_config.debug?
            Log.for("quickheadlines.feed").debug { "Running initial refresh to fetch feeds" }
          end
          spawn do
            begin
              refresh_all(active_config, cache, db_service)
            rescue ex
              Log.for("quickheadlines.feed").error(exception: ex) { "Initial refresh failed" }
            ensure
              StateStore.refreshing = false
            end
          end
          if active_config.debug?
            Log.for("quickheadlines.feed").debug { "Initial refresh started in background" }
          end
        else
          current_mtime = File.info(config_path).modification_time

          if current_mtime > last_mtime
            load_result = load_validated_config(config_path)
            if load_result.success && (new_config = load_result.config)
              active_config = new_config
              last_mtime = current_mtime

              if active_config.debug?
                Log.for("quickheadlines.feed").debug { "Config change detected. Reloaded feeds.yml" }
              end
            end
          end

          begin
            refresh_all(active_config, cache, db_service)
            if active_config.debug?
              Log.for("quickheadlines.feed").debug { "Refreshed feeds" }
            end
          rescue ex
            Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop refresh_all failed" }
          ensure
            # Always reset the refreshing flag — even on exception or timeout.
            # This prevents the loop from being permanently stuck.
            StateStore.refreshing = false
          end

          # save_feed_cache runs after refresh_all completes and should be fast.
          # It calls vacuum and cleanup, which are I/O-bound and bounded by DB size.
          save_feed_cache(cache, active_config.cache_retention_hours, active_config.max_cache_size_mb)

          # Help Boehm GC release memory back to OS on FreeBSD/BSD systems
          trigger_gc_collection

          refresh_duration = (Time.utc - refresh_start_time).total_seconds
          if refresh_duration > (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE) * 2
            Log.for("quickheadlines.feed").warn { "Refresh took #{refresh_duration.round(2)}s (expected #{active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE}s) - possible hang detected" }
          end
        end

        # Outer timeout guard: use sleep + select to avoid multi-timeout Pairing Heap
        # issues.  If refresh_all takes longer than outer_timeout, the outer rescue
        # catches the exception and the loop continues after 60s.
        sleep_duration = (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE).seconds
        outer_timeout = (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE * 3 // 2).seconds

        # Start the sleep in a separate fiber so we can timeout it
        sleep_done = Channel(Nil).new(1)
        spawn { sleep sleep_duration; sleep_done.send(nil) }
        select
        when sleep_done.receive
          # Normal sleep completed
        when timeout(outer_timeout)
          Log.for("quickheadlines.feed").error { "refresh loop sleep timed out after #{outer_timeout.total_seconds.round}s" }
        end

        break if QuickHeadlines.shutting_down?

        cycle_count += 1
        if cycle_count % heartbeat_interval == 0
          Log.for("quickheadlines.feed").debug { "Refresh loop heartbeat: #{cycle_count} cycles completed" }
        end
      rescue ex
        Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop outer handler: unhandled exception, restarting in 60s" }
        StateStore.refreshing = false
        cycle_count = 0
        sleep 60.seconds
        break if QuickHeadlines.shutting_down?
      end
    end
  end
end

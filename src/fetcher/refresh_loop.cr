require "time"
require "../config"
require "../models"
require "../storage"
require "../software_fetcher"
require "../websocket"
require "./feed_fetcher"
require "./software_util"
require "./refresh_health_monitor"
require "./refresh_semaphore"
require "./refresh_state"
require "./refresh_health_reporter"
require "../services/gc_collector"
require "../services/fiber_tracker"
require "../services/memory_manager_actor"

class RefreshLoop::CancelError < Exception
  def initialize(message : String = "Refresh cancelled")
    super(message)
  end
end

module RefreshLoop
  # -------------------------------------------------------------------------
  # Shared helpers
  # -------------------------------------------------------------------------

  private def self.cancel_check(cancel_ch : Channel(Nil)?) : Nil
    return unless cancel_ch
    select
    when cancel_ch.receive?
      raise CancelError.new
    when timeout(0.seconds)
    end
  end

  private def self.safe_channel_send(channel, value) : Nil
    channel.send(value)
  rescue Channel::ClosedError
  end

  private def self.safe_cancel(cancel_ch : Channel(Nil)?) : Nil
    return unless cancel_ch
    cancel_ch.send(nil) rescue nil
  end

  private def self.log_duration_warning(refresh_duration, active_config) : Nil
    expected_seconds = active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE
    hang_threshold = expected_seconds * 2
    if refresh_duration > hang_threshold
      Log.for("quickheadlines.feed").warn { "Refresh took #{refresh_duration.round(2)}s (expected #{expected_seconds}s) - possible hang detected" }
    end
  end

  private def self.debug_log(config : Config, &block) : Nil
    if config.debug?
      Log.for("quickheadlines.feed").debug { yield }
    end
  end

  private def self.best_available_feed(feed : Feed, fetched : FeedData?, existing : FeedData?) : FeedData
    return fetched if fetched && !fetched.failed?
    return existing if existing && !existing.failed?
    fetched || existing || FeedFetcher.instance.build_error_feed(feed, "Failed to fetch")
  end

  private def self.fallback_feed(feed : Feed, previous : FeedData?, error_message : String, context : String) : FeedData
    if previous && !previous.failed?
      Log.for("quickheadlines.feed").info { "#{context}: using cached data for #{feed.url}" }
      previous
    else
      FeedFetcher.instance.build_error_feed(feed, error_message)
    end
  end

  private def self.interruptible_sleep(total : Time::Span, outer_cap : Time::Span? = nil, chunk : Time::Span = 30.seconds) : Time::Span
    cap = outer_cap || total
    elapsed = Time::Span.zero
    while elapsed < total && elapsed < cap && !QuickHeadlines.shutting_down?
      step = {chunk, total - elapsed, cap - elapsed}.min
      select
      when timeout(step)
        elapsed += step
      end
    end
    elapsed
  end

  private def self.build_software_releases(software_config : SoftwareConfig?, item_limit : Int32) : Array(FeedData)
    QuickHeadlines::SoftwareUtil.build_software_releases(software_config, item_limit)
  end

  private def self.build_tab_feeds(
    tab_config : TabConfig,
    fetched_map : Hash(String, FeedData),
    existing_data : Hash(String, FeedData),
    item_limit : Int32,
  ) : Tab
    tab_feeds = tab_config.feeds.map do |feed|
      best_available_feed(feed, fetched_map[feed.url]?, existing_data[feed.url]?)
    end
    tab_releases = build_software_releases(tab_config.software_releases, item_limit)
    Tab.new(tab_config.name, tab_feeds, tab_releases)
  end

  private def self.collect_feed_configs(config : Config) : Hash(String, Feed)
    all_configs = {} of String => Feed
    config.feeds.each { |feed| all_configs[feed.url] = feed }
    config.tabs.each { |tab| tab.feeds.each { |feed| all_configs[feed.url] = feed } }
    all_configs
  end

  # -------------------------------------------------------------------------
  # Feed fetching
  # -------------------------------------------------------------------------

  private def self.fetch_single_feed_in_background(
    feed : Feed,
    config : Config,
    previous_feed_data : FeedData?,
    channel : Channel(FeedData?),
    index : Int32,
  ) : Nil
    acquire_semaphore
    begin
      RefreshHealthMonitor.feed_fetch_started
      result = fetch_single_feed_with_timeout(feed, config, previous_feed_data, index)
      safe_channel_send(channel, result)
    rescue ex : CancelError
      raise ex
    rescue ex : Exception
      Log.for("quickheadlines.feed").error(exception: ex) { "fetch_feeds_concurrently: error fetching #{feed.url}" }
      fallback = fallback_feed(feed, previous_feed_data, "Error: #{ex.class}", "fetch_feeds_concurrently: using cached data after outer error")
      safe_channel_send(channel, fallback)
    ensure
      RefreshHealthMonitor.feed_fetch_completed
      release_semaphore
    end
  end

  private def self.fetch_single_feed_with_timeout(
    feed : Feed,
    config : Config,
    previous_feed_data : FeedData?,
    index : Int32,
  ) : FeedData
    timeout_seconds = QuickHeadlines::Constants::FETCH_TIMEOUT_SECONDS
    result_channel = Channel(FeedData?).new(1)

    spawn(name: "feed_fetch_inner_#{index}") do
      begin
        fetch_result = FeedFetcher.instance.fetch(feed, config.item_limit, config.db_fetch_limit, previous_feed_data)
        result_channel.send(fetch_result)
      rescue ex : Exception
        Log.for("quickheadlines.feed").error(exception: ex) { "Fetch failed for #{feed.url}" }
        safe_channel_send(result_channel, nil)
      end
    end

    timed_out = false
    channel_result = nil

    select
    when value = result_channel.receive?
      channel_result = value
    when timeout(timeout_seconds.seconds)
      timed_out = true
      result_channel.close
    end

    if timed_out
      Log.for("quickheadlines.feed").warn { "fetch_single_feed_with_timeout: feed #{feed.url} timed out after #{timeout_seconds}s" }
      fallback_feed(feed, previous_feed_data, "Error: Fetch timeout after #{timeout_seconds}s", "fetch_single_feed_with_timeout")
    elsif channel_result
      channel_result
    else
      fallback_feed(feed, previous_feed_data, "Error: Fetch failed or nil", "fetch_single_feed_with_timeout")
    end
  end

  private def self.fetch_feeds_concurrently(
    all_configs : Hash(String, Feed),
    existing_data : Hash(String, FeedData),
    config : Config,
  ) : Hash(String, FeedData)
    channel = Channel(FeedData?).new(all_configs.size)
    feed_index = 0
    all_configs.each_value do |feed|
      current_index = feed_index
      feed_index += 1
      previous_feed_data = existing_data[feed.url]?
      spawn(name: "feed_fetch_outer_#{current_index}") do
        fetch_single_feed_in_background(feed, config, previous_feed_data, channel, current_index)
      end
      Fiber.yield
    end

    fetched_map = {} of String => FeedData
    completed = 0
    total_feeds = all_configs.size
    end_time = Time.utc + 10.minutes

    total_feeds.times do
      remaining = (end_time - Time.utc).total_seconds
      break if remaining <= 0

      select
      when feed_data = channel.receive?
        if feed_data
          fetched_map[feed_data.url] = feed_data
        elsif config.debug?
          Log.for("quickheadlines.feed").warn { "fetch_feeds_concurrently: failed to fetch feed" }
        end
        completed += 1
      when timeout(remaining.ceil.clamp(0.1, 10).seconds)
        break if completed >= total_feeds
      end
    end

    if completed < total_feeds
      Log.for("quickheadlines.feed").warn { "fetch_feeds_concurrently: fetched #{completed}/#{total_feeds} feeds" }
    end
    channel.close
    fetched_map
  end

  # -------------------------------------------------------------------------
  # Supervisor helpers
  # -------------------------------------------------------------------------

  private def self.reload_config_if_changed(config_path : String, state : State) : Nil
    current_mtime = begin
      File.info(config_path).modification_time
    rescue ex : File::NotFoundError
      debug_log(state.active_config) { "reload_config_if_changed: #{config_path} not found, skipping reload (#{ex.message})" }
      return
    end
    return unless current_mtime > state.last_mtime

    load_result = load_validated_config(config_path)
    if load_result.success && (new_config = load_result.config)
      state.active_config = new_config
      state.last_mtime = current_mtime
      debug_log(state.active_config) { "Config change detected. Reloaded feeds.yml" }
    end
  end

  private def self.check_memory_pressure(config : Config) : Bool
    memory_status = MemoryManagerActor.instance.get_memory_status
    case memory_status.pressure_level
    when .critical?
      Log.for("quickheadlines.feed").warn { "Skipping refresh due to critical memory pressure (RSS=#{memory_status.rss_mb.round(1)}MB)" }
      RefreshHealthMonitor.record_failure
      return true
    when .high?
      Log.for("quickheadlines.feed").warn { "Refresh proceeding with high memory pressure (RSS=#{memory_status.rss_mb.round(1)}MB)" }
    end
    false
  rescue ex : Exception
    Log.for("quickheadlines.feed").debug { "Memory pressure check failed: #{ex.message}" }
    false
  end

  private def self.post_refresh_cleanup(cache : FeedCache, config : Config, refresh_start_time : Time) : Nil
    cache.save(config.cache_retention_hours, config.max_cache_size_mb)
    GCCollector.maybe_collect
  end

  private def self.handle_refresh_failure(state : State) : Nil
    StateStore.refreshing = false
    RefreshHealthMonitor.record_failure
    state.reset_cycle_count
  end

  private def self.run_initial_refresh(state : State, cache : FeedCache, db_service : DatabaseService) : Nil
    debug_log(state.active_config) { "Running initial refresh to fetch feeds" }

    StateStore.refreshing = true
    config_for_initial = state.active_config
    cancel_ch = Channel(Nil).new(1)
    state.initial_cancel_ch = cancel_ch
    spawn(name: "initial_refresh") do
      begin
        refresh_all(config_for_initial, cache, db_service, cancel_ch)
      rescue CancelError
        Log.for("quickheadlines.feed").warn { "Initial refresh cancelled by supervisor" }
        RefreshHealthMonitor.record_failure
      rescue ex : Exception
        Log.for("quickheadlines.feed").error(exception: ex) { "Initial refresh failed" }
        RefreshHealthMonitor.record_failure
      ensure
        StateStore.refreshing = false
        state.initial_cancel_ch = nil
      end
    end

    debug_log(state.active_config) { "Initial refresh started in background" }
  end

  private def self.spawn_refresh_worker(config_snapshot : Config, cache : FeedCache, db_service : DatabaseService, cancel_ch : Channel(Nil)) : Channel(Nil)
    completion_channel = Channel(Nil).new(1)
    refresh_start = Time.utc
    spawn(name: "refresh_worker") do
      begin
        refresh_all(config_snapshot, cache, db_service, cancel_ch)
        duration = (Time.utc - refresh_start).total_seconds
        if config_snapshot.debug?
          Log.for("quickheadlines.feed").debug { "Refreshed feeds in #{duration.round(2)}s" }
        elsif duration > 120
          Log.for("quickheadlines.feed").warn { "refresh_all took #{duration.round(2)}s - long duration" }
        end
      rescue CancelError
        Log.for("quickheadlines.feed").warn { "Refresh worker cancelled by supervisor" }
        RefreshHealthMonitor.record_failure
      rescue ex : Exception
        Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop refresh_all failed" }
        RefreshHealthMonitor.record_failure
      end
      completion_channel.send(nil)
    end
    completion_channel
  end

  private def self.run_timed_refresh(state : State, cache : FeedCache, db_service : DatabaseService) : Float64
    return 0.0 if check_memory_pressure(state.active_config)

    StateStore.refreshing = true
    refresh_start_time = Time.utc
    outer_timeout = state.outer_timeout_seconds.seconds
    config_snapshot = state.active_config

    cancel_ch = Channel(Nil).new(1)
    completion_channel = spawn_refresh_worker(config_snapshot, cache, db_service, cancel_ch)

    select
    when completion_channel.receive?
      StateStore.refreshing = false
      refresh_duration = (Time.utc - refresh_start_time).total_seconds
      post_refresh_cleanup(cache, config_snapshot, refresh_start_time)
      refresh_duration
    when timeout(outer_timeout)
      safe_cancel(cancel_ch)
      StateStore.refreshing = false
      Log.for("quickheadlines.feed").error { "refresh_all timed out after #{outer_timeout.total_seconds.round}s - worker signalled to cancel" }
      RefreshHealthMonitor.record_failure
      GCCollector.maybe_collect
      (Time.utc - refresh_start_time).total_seconds
    end
  end

  private def self.sleep_between_cycles(state : State) : Nil
    sleep_duration = state.refresh_interval_seconds.seconds
    outer_sleep_timeout = state.sleep_timeout_seconds.seconds
    elapsed = interruptible_sleep(sleep_duration, outer_sleep_timeout)

    if elapsed >= outer_sleep_timeout && !QuickHeadlines.shutting_down?
      Log.for("quickheadlines.feed").error { "refresh loop sleep timed out after #{outer_sleep_timeout.total_seconds.round}s" }
    end
  end

  private def self.supervisor_cycle(state : State, config_path : String, cache : FeedCache, db_service : DatabaseService) : Nil
    check_stuck_recovery(state.stuck_threshold_seconds)

    if StateStore.refreshing?
      skip_count = state.increment_skips
      if skip_count >= State::MAX_CONSECUTIVE_SKIPS
        Log.for("quickheadlines.feed").error { "Force-resetting refreshing flag after #{skip_count} consecutive skips - previous refresh may be stuck" }
        StateStore.refreshing = false
        state.reset_skips
      else
        Log.for("quickheadlines.feed").warn { "Refresh already in progress, skipping (#{skip_count}/#{State::MAX_CONSECUTIVE_SKIPS})" }
        sleep state.refresh_interval_seconds.seconds
        return
      end
    else
      state.reset_skips
    end

    check_semaphore_health

    if state.first_run?
      state.mark_first_run_done
      run_initial_refresh(state, cache, db_service)
      interruptible_sleep(state.refresh_interval_seconds.seconds)
      if QuickHeadlines.shutting_down?
        safe_cancel(state.initial_cancel_ch)
      end
      return
    end

    reload_config_if_changed(config_path, state)
    refresh_duration = run_timed_refresh(state, cache, db_service)
    log_duration_warning(refresh_duration, state.active_config)

    sleep_between_cycles(state)
    state.increment_cycle
    log_heartbeat(state)
  end

  # -------------------------------------------------------------------------
  # Public API
  # -------------------------------------------------------------------------

  def self.refresh_all(config : Config, cache : FeedCache, db_service : DatabaseService, cancel_ch : Channel(Nil)? = nil) : Nil
    StateStore.update(&.copy_with(config_title: config.page_title, config: config))
    RefreshHealthMonitor.record_cycle_start

    all_configs = collect_feed_configs(config)
    Log.for("quickheadlines.feed").info { "refresh_all: starting - #{all_configs.size} feeds to fetch" }

    existing_data = (StateStore.feeds + StateStore.tabs.flat_map(&.feeds)).index_by(&.url)

    cancel_check(cancel_ch)

    fetched_map = fetch_feeds_concurrently(all_configs, existing_data, config)
    fetched_count = fetched_map.size
    missing_count = all_configs.size - fetched_count

    if missing_count > 0
      Log.for("quickheadlines.feed").warn { "refresh_all: fetched #{fetched_count}/#{all_configs.size} feeds, #{missing_count} missing or timed out" }
    else
      debug_log(config) { "refresh_all: fetched #{fetched_count}/#{all_configs.size} feeds successfully" }
    end

    new_feeds = config.feeds.map do |feed|
      best_available_feed(feed, fetched_map[feed.url]?, existing_data[feed.url]?)
    end
    new_tabs = config.tabs.map { |tab_config| build_tab_feeds(tab_config, fetched_map, existing_data, config.item_limit) }

    existing_data = nil

    cancel_check(cancel_ch)

    Log.for("quickheadlines.feed").info do
      "refresh_all: about to update StateStore - fetched_count=#{fetched_count}, missing_count=#{missing_count}, new_feeds=#{new_feeds.size}, new_tabs=#{new_tabs.size}"
    end

    StateStore.update do |state|
      state.copy_with(
        feeds: new_feeds,
        tabs: new_tabs,
        updated_at: Time.utc,
        refreshing: false
      )
    end

    fetched_map = nil

    EventBroadcaster.notify_feed_update(StateStore.updated_at.to_unix_ms)
    RefreshHealthMonitor.record_cycle_complete

    GCCollector.collect_now

    debug_log(config) { "refresh_all: complete - StateStore.feeds=#{new_feeds.size}, StateStore.tabs=#{new_tabs.size}" }
  rescue ex : Exception
    RefreshHealthMonitor.record_failure
    RefreshHealthMonitor.record_cycle_complete
    raise ex
  end

  def self.start(config_path : String, cache : FeedCache, db_service : DatabaseService) : Nil
    ensure_semaphore_initialized!

    load_result = load_validated_config(config_path)
    unless load_result.success && (initial_config = load_result.config)
      Log.for("quickheadlines.feed").error { "Failed to load config: #{load_result.error_message}" }
      return
    end

    state = State.new(initial_config, File.info(config_path).modification_time)
    cache.save(state.active_config.cache_retention_hours, state.active_config.max_cache_size_mb)

    spawn(name: "refresh_supervisor") do
      loop do
        break if QuickHeadlines.shutting_down?
        supervisor_cycle(state, config_path, cache, db_service)
      rescue ex : Exception
        Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop outer handler: unhandled exception, restarting in 60s" }
        handle_refresh_failure(state)
        interruptible_sleep(60.seconds)
        break if QuickHeadlines.shutting_down?
      end
    end

    start_health_reporter
  end
end

alias RefreshHealthMonitor = RefreshLoop::RefreshHealthMonitor

def start_refresh_loop(config_path : String, cache : FeedCache, db_service : DatabaseService)
  RefreshLoop.start(config_path, cache, db_service)
end

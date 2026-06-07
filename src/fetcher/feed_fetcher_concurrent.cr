require "log"
require "../config"
require "../models"
require "../constants"
require "./feed_fetcher"
require "./semaphore_pool"

# Per-feed concurrent fetch logic used by the refresh loop.
#
# Splits the "what to fetch" strategy (`feed_fetcher.cr`) from the
# "how to fetch concurrently" mechanism (this file). Owns:
# - The per-feed fiber spawn + per-feed timeout + fallback policy
# - The channel-based fan-in and the overall refresh timeout
# - The "best available feed" resolution (fresh-good > stale-good >
#   fresh-bad > stale-bad > synthetic error) used by `refresh_all` and
#   the tab builder
#
# The semaphore that gates the number of in-flight fetches is passed
# in as a `SemaphorePool` instance (see `semaphore_pool.cr`) so the
# module owns no global state.
module RefreshLoop
  module FeedFetcherConcurrent
    # Hard ceiling on the wall-clock time spent in `fetch_all`. If the
    # fan-in channel does not produce a result for every feed inside
    # this window, `fetch_all` returns what it has and logs a warning.
    OVERALL_FETCH_TIMEOUT = 10.minutes

    def self.fetch_all(
      all_configs : Hash(String, Feed),
      existing_data : Hash(String, FeedData),
      config : Config,
      semaphore : SemaphorePool,
    ) : Hash(String, FeedData)
      channel = Channel(FeedData?).new(all_configs.size)
      feed_index = 0
      all_configs.each_value do |feed|
        current_index = feed_index
        feed_index += 1
        previous_feed_data = existing_data[feed.url]?
        spawn(name: "feed_fetch_outer_#{current_index}") do
          fetch_one(feed, config, previous_feed_data, channel, current_index, semaphore)
        end
        Fiber.yield
      end

      fetched_map = {} of String => FeedData
      completed = 0
      total_feeds = all_configs.size

      end_time = Time.utc + OVERALL_FETCH_TIMEOUT
      total_feeds.times do
        remaining = (end_time - Time.utc).total_seconds
        break if remaining <= 0

        select
        when feed_data = channel.receive?
          if feed_data
            fetched_map[feed_data.url] = feed_data
          elsif config.debug?
            Log.for("quickheadlines.feed").warn { "fetch_all: failed to fetch feed" }
          end
          completed += 1
        when timeout(remaining.ceil.clamp(0.1, 10).seconds)
          if completed >= total_feeds
            break
          end
        end
      end

      if completed < total_feeds
        Log.for("quickheadlines.feed").warn { "fetch_all: fetched #{completed}/#{total_feeds} feeds" }
      end
      channel.close
      fetched_map
    end

    # Resolve the best available data for a feed.
    # Priority: fresh-good > stale-good > fresh-bad > stale-bad > synthetic error
    def self.best_available_feed(feed : Feed, fetched : FeedData?, existing : FeedData?) : FeedData
      return fetched if fetched && !fetched.failed?
      return existing if existing && !existing.failed?
      fetched || existing || FeedFetcher.instance.build_error_feed(feed, "Failed to fetch")
    end

    private def self.fetch_one(
      feed : Feed,
      config : Config,
      previous_feed_data : FeedData?,
      channel : Channel(FeedData?),
      index : Int32,
      semaphore : SemaphorePool,
    ) : Nil
      semaphore.acquire
      begin
        RefreshHealthMonitor.feed_fetch_started
        result = fetch_one_with_timeout(feed, config, previous_feed_data, index)
        begin
          channel.send(result)
        rescue Channel::ClosedError
        end
      rescue ex : CancelError
        # Re-raise so the supervisor's CancelError rescue fires and the
        # cancellation is logged distinctly from a fetch error. `ensure` still
        # runs, releasing the semaphore and decrementing the in-progress count.
        # This is defense-in-depth: today CancelError is only raised in
        # refresh_all's cancel_check, but if cancel_check is ever pushed deeper
        # (e.g. into the per-feed fetch path), this prevents it from being
        # silently converted into a fallback FeedData.
        raise ex
      rescue ex : Exception
        Log.for("quickheadlines.feed").error(exception: ex) { "fetch_one: error fetching #{feed.url}" }
        fallback = fallback_feed(feed, previous_feed_data, "Error: #{ex.class}", "fetch_one: using cached data after outer error")
        begin
          channel.send(fallback)
        rescue Channel::ClosedError
        end
      ensure
        RefreshHealthMonitor.feed_fetch_completed
        semaphore.release
      end
    end

    private def self.fetch_one_with_timeout(
      feed : Feed,
      config : Config,
      previous_feed_data : FeedData?,
      index : Int32,
    ) : FeedData
      timeout_seconds = QuickHeadlines::Constants::FETCH_TIMEOUT_SECONDS

      # Buffered channel (size 1) prevents inner fiber from blocking on send()
      # after timeout. Without buffering, the fiber would block forever waiting
      # for a receiver that already returned.
      result_channel = Channel(FeedData?).new(1)

      spawn(name: "feed_fetch_inner_#{index}") do
        begin
          fetch_result = FeedFetcher.instance.fetch(feed, config.item_limit, config.db_fetch_limit, previous_feed_data)
          result_channel.send(fetch_result)
        rescue ex : Exception
          Log.for("quickheadlines.feed").error(exception: ex) { "Fetch failed for #{feed.url}" }
          begin
            result_channel.send(nil)
          rescue Channel::ClosedError
          end
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
        Log.for("quickheadlines.feed").warn { "fetch_one_with_timeout: feed #{feed.url} timed out after #{timeout_seconds}s" }
        fallback_feed(feed, previous_feed_data, "Error: Fetch timeout after #{timeout_seconds}s", "fetch_one_with_timeout")
      elsif channel_result
        channel_result
      else
        fallback_feed(feed, previous_feed_data, "Error: Fetch failed or nil", "fetch_one_with_timeout")
      end
    end

    # Returns previous FeedData if it exists and is not a failed feed,
    # otherwise builds a synthetic error feed. Used by all per-feed
    # fallback paths (timeout, exception, nil result, outer error) so the
    # "use cached, else build error" policy lives in exactly one place.
    private def self.fallback_feed(feed : Feed, previous : FeedData?, error_message : String, context : String) : FeedData
      if previous && !previous.failed?
        Log.for("quickheadlines.feed").info { "#{context}: using cached data for #{feed.url}" }
        previous
      else
        FeedFetcher.instance.build_error_feed(feed, error_message)
      end
    end
  end
end

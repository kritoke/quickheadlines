# Retry, abort, and backoff logic extracted from FeedFetcher.
module FetcherRetry
  private record FetchAbortDecision,
    should_abort : Bool,
    reason : String? do
    def abort? : Bool
      should_abort
    end
  end

  private record FetchErrorResult,
    data : FeedData?,
    retries : Int32

  # Determine if a fetch should be aborted due to timeout, redirects, or max retries.
  private def should_abort_fetch?(feed : Feed, elapsed_seconds : Float, retries : Int32, redirects : Int32, timeout_seconds : Int32) : FetchAbortDecision
    if elapsed_seconds > timeout_seconds
      return FetchAbortDecision.new(true, "Error: Fetch timeout after #{timeout_seconds}s (retries: #{retries})")
    end

    if redirects > QuickHeadlines::Constants::MAX_REDIRECTS
      return FetchAbortDecision.new(true, "Error: Too many redirects (#{redirects})")
    end

    if retries >= QuickHeadlines::Constants::MAX_RETRIES
      return FetchAbortDecision.new(true, "Error: Failed after #{retries} retries")
    end

    FetchAbortDecision.new(false, nil)
  end

  # Handle an abort condition by returning stale cache or error feed.
  private def handle_abort_condition(feed : Feed, effective_item_limit : Int32, previous_data : FeedData?, decision : FetchAbortDecision) : FeedData?
    return unless decision.abort?

    message = decision.reason || "Error: Unknown fetch error"
    Log.for("quickheadlines.feed").warn { "fetch_feed(#{feed.url}) #{message}" }
    if stale_cache = get_stale_cached_feed(feed, effective_item_limit, previous_data)
      stale_cache
    else
      build_error_feed(feed, message)
    end
  end

  # Handle a fetch exception — all errors get retries with exponential backoff.
  # Timeouts are handled specially to trigger retry and return nil data (so next attempt can succeed);
  # other errors return stale cache if available to avoid disrupting the user experience.
  private def handle_fetch_exception(ex : Exception, feed : Feed, effective_item_limit : Int32, previous_data : FeedData?, retries : Int32) : FetchErrorResult
    error_msg = ex.message
    is_timeout = error_msg.is_a?(String) && error_msg.downcase.includes?("timeout")

    if is_timeout
      Log.for("quickheadlines.feed").warn { "fetch_feed(#{feed.url}) timeout: #{error_msg}" }
      # Timeouts: return nil data and increment retries with backoff
      # This allows the next iteration to retry without stale cache getting in the way
      FetchErrorResult.new(nil, handle_timeout_error(feed, retries))
    else
      Log.for("quickheadlines.feed").error(exception: ex) { "fetch_feed(#{feed.url})" }
      # Non-timeout errors: try stale cache to avoid disrupting user experience,
      # but still increment retries to prevent infinite loops on persistent failures
      new_retries = retries + 1
      if stale_cache = get_stale_cached_feed(feed, effective_item_limit, previous_data)
        FetchErrorResult.new(stale_cache, new_retries)
      else
        FetchErrorResult.new(build_error_feed(feed, "Error: #{ex.class} - #{error_msg}"), new_retries)
      end
    end
  end

  # Increment retry count and sleep with exponential backoff.
  private def handle_timeout_error(feed : Feed, retries : Int32) : Int32
    new_retries = retries + 1
    backoff_seconds = calculate_backoff(feed, new_retries)
    Log.for("quickheadlines.feed").warn { "fetch_feed(#{feed.url}) timeout, retry #{new_retries}/#{QuickHeadlines::Constants::MAX_RETRIES} in #{backoff_seconds}s" }
    sleep(backoff_seconds.seconds)
    new_retries
  end

  private def calculate_backoff(feed : Feed, retries : Int32) : Int32
    Math.min(QuickHeadlines::Constants::MAX_BACKOFF_SECONDS, 2 ** retries)
  end
end

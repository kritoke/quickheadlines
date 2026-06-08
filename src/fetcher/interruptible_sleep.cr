require "../module"

# Chunked sleep primitive that checks `QuickHeadlines.shutting_down?`
# between each chunk.
#
# Both the refresh supervisor and the periodic health reporter need
# to sleep for a while (one to wait between refresh cycles, the
# other to wait between status log lines) while still being
# responsive to a shutdown signal. A plain `sleep` would block for
# the full duration; this helper breaks the wait into
# `chunk`-sized timeouts that re-check the shutdown flag between
# each.
#
# The previous design had two private copies of this helper
# (one in `Supervisor`, one in `HealthReporter`). The reporter's
# copy was a deliberate stop-gap because the parent module's
# `interruptible_sleep` was `private` and unreachable from a
# sub-module. This is the shared replacement.
#
# Replaces: `quickhea-aiu`.
module RefreshLoop
  module InterruptibleSleep
    # Default chunk size — gives a responsive shutdown signal
    # without burning CPU. Both consumers used the same value
    # before this extraction.
    DEFAULT_CHUNK = 30.seconds

    # Sleep for up to `total`. Returns the actual elapsed time
    # (which is < total if shutdown was signaled, or == total on
    # natural completion).
    #
    # `outer_cap` adds a hard ceiling: if non-nil, the loop exits
    # when elapsed >= outer_cap even if `total` has not been
    # reached. Used by `Supervisor.sleep_between_cycles` to bound
    # the wait independent of the configured refresh interval.
    #
    # `chunk` controls the granularity of the internal `select`
    # timeout. Smaller chunks give more responsive shutdown
    # (worst case: chunk seconds of delay) at the cost of more
    # `select` iterations.
    def self.sleep(total : Time::Span, outer_cap : Time::Span? = nil, chunk : Time::Span = DEFAULT_CHUNK) : Time::Span
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
  end
end

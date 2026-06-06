# Dev-only simulation helpers for the refresh loop.
#
# These methods mutate production observability state (timestamps,
# counters) to exercise supervisor recovery paths. They are not used by
# the production supervisor and should only be invoked from dev
# tooling (e.g., the `/api/_dev/force_stuck` HTTP endpoint, which is
# gated by QUICKHEADLINES_ENABLE_DEV_ENDPOINT and restricted to
# localhost). They are kept under `src/dev_tools/` rather than the
# production class to make the dev/prod separation explicit.
module QuickHeadlines::DevRefreshSimulator
  # Simulate the "stuck refresh" state for supervisor recovery testing.
  # Sets the last-refresh-start timestamp to N seconds in the past and
  # zeroes last-refresh-complete, which causes
  # `RefreshHealthMonitor.stuck?` to return true.
  def self.force_stuck!(seconds : Int32 = 600) : Nil
    now_ms = Time.utc.to_unix_ms
    RefreshLoop::RefreshHealthMonitor.last_refresh_start_for_testing = now_ms - (seconds * 1000)
    RefreshLoop::RefreshHealthMonitor.last_refresh_complete_for_testing = 0_i64
    Log.for("quickheadlines.dev").info { "DevRefreshSimulator: simulated stuck state for #{seconds}s" }
  end
end

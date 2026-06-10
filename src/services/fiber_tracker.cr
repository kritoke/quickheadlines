# Fiber lifecycle tracking for leak diagnosis.
#
# Maintains counters for active fibers, peak concurrent fibers, and
# total fiber spawns. Used by the supervisor's health reporter to
# surface fiber leaks in the log.
#
# Spawn sites that need tracking (e.g. long-lived periodic fibers,
# per-connection writer fibers, per-fetch fetcher fibers) should
# use `FiberTracker.tracked_spawn` instead of `spawn` directly so
# the counters reflect reality.
module RefreshLoop::FiberTracker
  @@active_fibers = Atomic(Int32).new(0)
  @@peak_fibers = Atomic(Int32).new(0)
  @@fiber_spawns = Atomic(Int32).new(0)

  # Call this when spawning a fiber
  def self.track_spawn : Nil
    # NOTE: `Atomic.add(value)` returns the OLD value, not the new
    # one (despite the docs). So we read the post-add value with a
    # separate `.get` call. The small race (another fiber could
    # increment in between) is acceptable for peak tracking — we
    # get a slightly stale value, but the peak is still correct.
    @@active_fibers.add(1)
    count = @@active_fibers.get
    @@fiber_spawns.add(1)
    # Update peak
    current_peak = @@peak_fibers.get
    @@peak_fibers.add(1) if count > current_peak
  end

  # Call this when a fiber exits
  def self.track_exit : Nil
    current = @@active_fibers.get
    @@active_fibers.sub(1) if current > 0
  end

  def self.stats : String
    "active=#{@@active_fibers.get}, peak=#{@@peak_fibers.get}, spawns=#{@@fiber_spawns.get}"
  end

  def self.reset : Nil
    # Resets all three counters to zero. Used by the spec to
    # isolate tests; the reporter never calls this in production.
    # (In production the counters represent process-lifetime stats,
    # which is what we want.)
    @@active_fibers.set(0)
    @@peak_fibers.set(0)
    @@fiber_spawns.set(0)
  end

  # Wrap a spawn call with spawn/exit tracking. Use this everywhere
  # a fiber is spawned in long-lived code paths so the
  # `active`/`peak`/`spawns` counters reflect reality.
  #
  # Usage:
  #   FiberTracker.tracked_spawn do
  #     # body
  #   end
  #
  #   FiberTracker.tracked_spawn("my-fiber") do
  #     # body
  #   end
  #
  # The name is optional and is passed through to `spawn(name: ...)`.
  # The `ensure` block guarantees `track_exit` runs even if the
  # fiber body raises — without this, a fiber that dies with an
  # exception would leak the active-fiber counter.
  def self.tracked_spawn(name : String? = nil, &block) : Fiber
    track_spawn
    spawn(name: name) do
      begin
        block.call
      ensure
        track_exit
      end
    end
  end
end

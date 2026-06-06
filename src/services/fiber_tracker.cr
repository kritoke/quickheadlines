# Fiber lifecycle tracking for leak diagnosis.
#
# Maintains counters for active fibers, peak concurrent fibers, and
# total fiber spawns. Used by the supervisor's health reporter to
# surface fiber leaks in the log. Not yet wired into the spawn path
# (track_spawn / track_exit are available but the spawn sites don't
# call them yet — the counters reflect the post-load baseline).
module RefreshLoop::FiberTracker
  @@active_fibers = Atomic(Int32).new(0)
  @@peak_fibers = Atomic(Int32).new(0)
  @@fiber_spawns = Atomic(Int32).new(0)

  # Call this when spawning a fiber
  def self.track_spawn : Nil
    count = @@active_fibers.add(1)
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
    @@peak_fibers.set(@@active_fibers.get)
  end
end

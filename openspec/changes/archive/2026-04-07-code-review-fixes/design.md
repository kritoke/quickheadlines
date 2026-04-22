## Context

The codebase has several thread safety, race condition, and resource management issues identified during code review:

1. **FeedFetcher singleton** uses `@@instance ||= ...` which is not atomic in Crystal - multiple fibers could create multiple instances
2. **RateLimiter cleanup** runs on every `allowed?` call, blocking on cleanup lock and causing performance issues
3. **Refresh loop** can overlap - if a refresh takes longer than the interval, the next refresh starts before the previous completes
4. **WebSocket registration** increments IP count before adding connection, leaking count on exception
5. **Timing-safe comparison** manually implemented instead of using `Crypto::ConstantTimeCompare`
6. **Manual transaction handling** instead of Crystal's `db.transaction {}` block
7. **Cluster repository** has hardcoded 1000 limit

## Goals / Non-Goals

**Goals:**
- Fix all thread safety issues identified in code review
- Prevent refresh cycle overlaps
- Improve exception safety in WebSocket registration
- Use standard library crypto for constant-time comparison
- Make cluster limit configurable

**Non-Goals:**
- No schema changes or database migrations
- No API changes
- No frontend changes

## Decisions

### 1. FeedFetcher Singleton Thread Safety

**Decision:** Use `@@mutex.synchronize` around singleton initialization.

```crystal
@@mutex = Mutex.new

def self.instance : FeedFetcher
  @@mutex.synchronize { @@instance ||= FeedFetcher.new(FeedCache.instance) }
end
```

**Rationale:** Crystal's `||=` is not atomic for class variables. Multiple fibers could simultaneously create instances.

### 2. RateLimiter Background Cleanup

**Decision:** Spawn a dedicated cleanup fiber that runs every 60 seconds.

```crystal
@@cleanup_fiber : Fiber?
@@cleanup_mutex = Mutex.new

def self.start_cleanup_fiber
  @@cleanup_mutex.synchronize do
    return if @@cleanup_fiber
    @@cleanup_fiber = spawn do
      loop do
        sleep 60.seconds
        cleanup_stale_instances
      end
    end
  end
end
```

**Rationale:** Cleanup on every request causes lock contention and latency spikes.

### 3. Refresh Cycle Lock

**Decision:** Add a `@@refresh_mutex` to prevent overlapping refresh cycles.

```crystal
@@refresh_mutex = Mutex.new

def refresh_all(config : Config)
  @@refresh_mutex.synchronize do
    # existing refresh logic
  end
end
```

**Rationale:** Current code only warns about overlap but doesn't prevent it.

### 4. WebSocket Registration Exception Safety

**Decision:** Move all state modifications under single mutex with begin/ensure.

```crystal
def register(ws : HTTP::WebSocket, ip : String) : Bool
  @connections_mutex.synchronize do
    # validation
    # IP count increment
    # connection creation
    # connection add
  ensure
    # cleanup on exception
    decrement_ip_count(ip) if failed
  end
end
```

**Rationale:** Current code increments IP count outside the mutex, leaking counts on exceptions.

### 5. Crypto::ConstantTimeCompare

**Decision:** Replace manual implementation with standard library.

```crystal
require "crypto"

def timing_safe_compare(a : String, b : String) : Bool
  return false unless a.bytesize == b.bytesize
  Crypto::ConstantTimeCompare(a, b)
end
```

**Rationale:** Standard library is battle-tested and clearer intent.

### 6. db.transaction Block

**Decision:** Replace manual BEGIN/COMMIT/ROLLBACK with Crystal's block form.

```crystal
db.transaction do
  feed_id = upsert_feed(feed_data)
  insert_items(feed_id, feed_data.items)
end
```

**Rationale:** Automatic rollback on exception, cleaner code.

### 7. Configurable Cluster Limit

**Decision:** Add `cluster_fetch_limit` to ClusteringConfig struct.

```crystal
struct ClusteringConfig
  property max_fetch_items : Int32 = 1000  # rename from implied limit
end
```

**Rationale:** Hardcoded 1000 is arbitrary and should be configurable.

## Risks / Trade-offs

[Thread safety] → Existing code may have subtle race conditions not caught → Extensive testing under load

[Refresh mutex] → Could cause refresh requests to queue up if system under heavy load → Acceptable since refreshes should complete quickly

[Background fiber] → Cleanup fiber could deadlock if exceptions occur → Wrap in rescue block

## Migration Plan

1. Add new mutexes and cleanup fiber
2. Update FeedFetcher singleton
3. Update RateLimiter with background cleanup
4. Add refresh mutex
5. Fix WebSocket registration
6. Update timing_safe_compare
7. Update transaction handling
8. Add cluster config option
9. Build and test

No rollback needed - these are additive safety improvements.

## Open Questions

None - all implementation details are clear from code review.

# Memory Audit — Unbounded Data Structures

This document audits all Hash/Array/Channel in code paths that run
for the lifetime of the process. Each entry documents the cap (if any),
eviction strategy, what happens when the cap is hit, and whether
retention is measured in the memory log.

## Summary Table

| Structure | File | Cap | Eviction | Measured? | Action? |
|-----------|------|-----|----------|-----------|---------|
| `AppStateService.@memory_history` | `app_state_service.cr:16` | 500 | FIFO (shift) | ✅ via memory_history_summary | OK |
| `AppStateService.@current` | `app_state_service.cr:22` | 1 | Replace | ✅ via StateStore | OK |
| `EventBroadcaster.@@client_history` | `event_broadcaster.cr` | 1000 | FIFO (shift) | ✅ via client_history_summary | OK |
| `EventBroadcaster.@@clients` | `event_broadcaster.cr` | None | Remove on close | ✅ via client_count | ⚠️ task-vnk.3 |
| `RateLimiter.@@allowed_cache` | `rate_limiter.cr` | 256 | Clear all | ✅ via cache_size | OK |
| `FaviconCache.@@cache` | `favicon_cache.cr` | 200 | LRU evict | ❌ | ⚠️ add metric |
| `FaviconActor.@client_pool` | `favicon_storage.cr:42` | None | None | ✅ via client_pool_size | 🔴 task-vnk.2 |
| `SocketManager.@connections` | `socket_manager.cr` | MAX_CONNECTIONS (100) | Close oldest | ✅ via connection_count | ⚠️ task-vnk.3 |
| `SocketManager.@ip_counts` | `socket_manager.cr` | None | Decrement on close | ❌ | ⚠️ task-vnk.3 |
| `StringIntern.@@pool` | `string_pool.cr` | 10000 | Evict oldest half | ✅ via size | OK |
| `MemoryManagerActor.@cleanup_handlers` | `memory_manager_actor.cr:132` | None | None | ❌ | ⚠️ small |
| `Actor.@mailbox` | `actor.cr:62` | 100 (configurable) | Block sender | ❌ | ⚠️ task-vnk.4 |
| `FiberTracker.@@active_fibers` | `fiber_tracker.cr` | N/A (Atomic) | N/A | ✅ via stats | OK |
| `Monitoring.@@last_rss_mb` | `monitoring.cr` | N/A (scalar) | N/A | ✅ via report_status | OK |
| `TaskMetadata.@@*` | `task_metadata.cr` | N/A (scalars) | N/A | ❌ | OK |

## Detailed Analysis

### 🔴 Critical: FaviconActor.@client_pool (task-vnk.2)

**Location**: `src/favicon_storage.cr:42`

```crystal
@client_pool : Hash(String, HTTP::Client) = {} of String => HTTP::Client
```

**Issue**: No cap. Each unique feed host adds an HTTP::Client with its own socket pool. Never evicted.

**Impact**: With 214 feeds across many hosts, this grows unbounded over time.

**Fix**: Add LRU eviction with cap (e.g., 50 clients). Evict least-recently-used when cap hit.

---

### ⚠️ Warning: EventBroadcaster.@@clients (task-vnk.3)

**Location**: `src/websocket/event_broadcaster.cr`

```crystal
@@clients = [] of HTTP::WebSocket
```

**Issue**: Clients are removed on close, but half-closed sockets may linger.

**Impact**: Writer fibers spawned per connection hold references to large broadcast payloads.

**Fix**: Add connection age tracking, force-close connections older than threshold.

---

### ⚠️ Warning: SocketManager.@connections (task-vnk.3)

**Location**: `src/websocket/socket_manager.cr`

```crystal
@connections = [] of Connection
@ip_counts = {} of String => Int32
@last_activity = {} of HTTP::WebSocket => Time
```

**Issue**: Capped at MAX_CONNECTIONS (100), but cleanup relies on detecting closed sockets. Half-closed TCP may not be detected.

**Impact**: Writer fibers hold references to pending broadcast messages.

**Fix**: Add connection age tracking, force-close stale connections.

---

### ⚠️ Warning: Actor.@mailbox (task-vnk.4)

**Location**: `src/infrastructure/actor.cr:62`

```crystal
@mailbox : Channel(Message)
```

**Issue**: Each `def_call` allocates a fresh `Channel(String).new(1)` for reply. If caller raises between send and receive, the channel + struct linger.

**Impact**: High call rates = hundreds of short-lived channels/min.

**Fix**: Pool reply channels or use a single shared channel with correlation IDs.

---

### ⚠️ Warning: FaviconCache.@@cache

**Location**: `src/favicon_cache.cr`

```crystal
@@cache = {} of String => CacheEntry
@@access_order = [] of String
```

**Issue**: Capped at 200 entries with LRU eviction, but not measured in memory log.

**Impact**: Small (200 entries × ~1KB each = ~200KB).

**Fix**: Add `FaviconCache.size` to memory diagnostics.

---

### ✅ OK: AppStateService.@memory_history

**Location**: `src/services/app_state_service.cr:16`

```crystal
@memory_history = [] of {time: Time, rss_mb: Float64, feeds_count: Int32, items_count: Int32}
@memory_history_max_entries = 500
```

**Cap**: 500 entries. **Eviction**: FIFO (shift when full). **Measured**: Yes, via `memory_history_summary`.

---

### ✅ OK: RateLimiter.@@allowed_cache

**Location**: `src/rate_limiter.cr`

```crystal
CACHE_MAX_ENTRIES = 256
@@allowed_cache = {} of String => {Int64, Bool}
```

**Cap**: 256 entries. **Eviction**: Clear all when cap hit. **Measured**: Yes, via `cache_size`.

---

### ✅ OK: StringIntern.@@pool

**Location**: `src/utils/string_pool.cr`

```crystal
MAX_POOL_SIZE = 10_000
@@pool = {} of String => String
```

**Cap**: 10,000 entries. **Eviction**: Remove oldest half when cap hit. **Measured**: Yes, via `size`.

---

## Action Items

1. **task-vnk.2**: Cap FaviconActor.@client_pool at 50 with LRU eviction
2. **task-vnk.3**: Add connection age tracking to SocketManager and EventBroadcaster
3. **task-vnk.4**: Pool Actor reply channels or reduce allocations
4. **Add metric**: Include FaviconCache.size in memory diagnostics

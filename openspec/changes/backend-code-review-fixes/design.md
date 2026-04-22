## Context

The QuickHeadlines backend (Crystal 1.18.2 / Athena framework) serves an RSS/Atom feed aggregator with SQLite persistence, MinHash/LSH story clustering, WebSocket real-time updates, favicon management, and a Svelte frontend. It was reviewed for maintainability, security, performance, and error handling. The review found 20+ issues, the most severe being a security flaw where admin endpoints are unauthenticated by default — a critical finding for the planned public-facing deployment.

**Current Architecture:**
- Controllers → StateStore (global mutable snapshot) / FeedCache (singleton + mixin soup) → Repositories → SQLite
- Free functions scattered across `utils.cr`, `cache_utils.cr`, `database.cr`
- Two independent database migration systems coexist
- Duplicate `Item` and `TimelineItem` types across `models.cr`, `feed_service.cr`, `story_repository.cr`

## Goals / Non-Goals

**Goals:**
- Eliminate all P0 security vulnerabilities before public deployment
- Establish a maintainable, self-consistent domain model
- Reduce mutex contention and N+1 query patterns in hot paths
- Replace bare exception catches and `STDERR.puts` logging with typed errors and structured logging
- Split oversized classes to improve testability and clarity

**Non-Goals:**
- Full rewrite of any subsystem — changes must be incremental and backward-compatible
- Changing the public HTTP API surface (endpoint paths, JSON response shapes)
- Migrating from SQLite to another storage engine
- Adding new user-facing features
- Removing the `BakedFileSystem` / embedded frontend approach

## Decisions

### D1: Admin Auth — Fail-Closed by Default

**Decision:** When `ADMIN_SECRET` env var is absent or empty, admin endpoints return 401.

**Rationale:** The current code returns `true` (allow) when `ADMIN_SECRET` is unset. This is dangerous for public-facing servers. The fix is one line: `return false if secret.nil? || secret.empty?`.

**Alternative:** Require `ADMIN_SECRET` to be set and fail startup if absent. Rejected — would break existing deployments where the env var is set post-startup via container orchestration.

**Risk:** Existing deployments with no `ADMIN_SECRET` set will suddenly get 401s. → Mitigation: Document the breaking change, provide a migration guide.

---

### D2: Image Proxy — Allowlist Over Denylist

**Decision:** Replace `Utils.private_host?` denylist with an explicit `ALLOWED_PROXY_DOMAINS` constant containing only the domains that the application actually uses for images.

**Rationale:** SSRF defenses based on private IP ranges are bypassable via DNS rebinding, IPv6 variants, and leaked internal DNS. An allowlist of known-good domains is far more robust.

**Alternatives considered:**
- *DNS rebinding protection*: Complex to implement correctly in Crystal stdlib
- *IP allowlist*: Brittle — cloud provider IPs change
- *Keep denylist + add more ranges*: Whack-a-mole, still bypassable

**Risk:** Legitimate feeds using images from new domains will break → Mitigation: The allowlist can be extended via config in future; initially populate with current hardcoded domains plus a note in the admin UI.

---

### D3: Request Body Size Limits — 1MB Cap + Streaming

**Decision:** Add a `MAX_REQUEST_BODY_SIZE = 1_048_576` constant. All `gets_to_end` calls on request bodies are replaced with a helper that reads up to this limit and raises on overflow.

**Rationale:** `gets_to_end` reads the entire body into memory. An attacker sending a multi-GB POST body would exhaust server memory.

**Alternatives considered:**
- *Use Athena's built-in request size limit*: No such built-in in Athena 0.21.x
- *Limit at nginx level*: Doesn't protect against direct local access

**Risk:** Legitimate users uploading large configs could be rejected → Mitigation: 1MB is sufficient for all config payloads; feeds are fetched server-side.

---

### D4: Canonical Domain Model — Single Namespace

**Decision:** Create `src/domain/items.cr` containing:
- `QuickHeadlines::Domain::FeedItem` — flat struct (id, title, link, pub_date, version, comment_url, commentary_url, feed_id)
- `QuickHeadlines::Domain::TimelineEntry` — flat struct with cluster fields

Deprecate:
- `Item` in `models.cr`
- `TimelineItem` in `models.cr`
- `TimelineItem` in `story_repository.cr`
- `Item` in `feed_service.cr`

**Rationale:** Duplicate types with identical field names but different structures cause bugs at boundary crossings. The flat struct approach (instead of wrapping `FeedItem` inside `TimelineEntry`) matches how the data flows through repositories → services → controllers.

**Migration:** Keep old records as aliases pointing to new ones during a transition window.

---

### D5: Namespace Hierarchy

**Decision:** Move all top-level types under `QuickHeadlines::`:
- `Constants` → `QuickHeadlines::Constants`
- `StateStore` → `QuickHeadlines::State::StateStore`
- `FeedCache` → `QuickHeadlines::Storage::FeedCache` (the singleton facade only)
- Mixins remain module-level includes (e.g., `ClusteringRepository` stays as-is but the standalone classes go under `QuickHeadlines::Storage`)

**Rationale:** Unnamespaced types collide with third-party shards. `Log` module, `File` module, etc. in Crystal stdlib mean global namespace is precious.

**Trade-off:** Requires updating hundreds of `require` statements and type references. This is mechanical but wide-reaching.

**Risk:** Missing a reference causes compile errors → Mitigation: Use a script to automate the rename via sed before manual cleanup.

---

### D6: Dual Migration System — Consolidate to Versioned Migrations

**Decision:** `DatabaseService#initialize` removes its inline `add_column_if_missing` calls and `migrate_lsh_bands_if_needed`. The `create_schema` method only sets PRAGMAs and calls `Schema::FEEDS_TABLE`, `Schema::ITEMS_TABLE`, `Schema::LSH_BANDS_TABLE`. All schema evolution goes through `run_migrations` in `database.cr`.

**Rationale:** The versioned migration system with `schema_info` table is the correct approach. The ad-hoc `add_column_if_missing` at startup was a workaround that creates column-order inconsistency and makes the schema impossible to reproduce reliably.

**Risk:** If there are existing databases where the ad-hoc migrations ran but the versioned migrations didn't, some columns might be missing → Mitigation: The versioned migrations handle all required columns with `add_column_if_not_exists`.

---

### D7: Dead Code Removal

**Decision:** Remove these in one focused commit:
- `DatabaseService#get_timeline_items` (76 lines, never called)
- `FeedState` and all subtypes (state machine with no consumers)
- `StoryGroup` record
- `ClusteredTimelineItem` record and `to_clustered` helper
- `StateStore#feeds_for_tab_impl` and `StateStore#all_timeline_items_impl`

**Rationale:** Dead code confuses new developers and creates maintenance burden. `git blame` shows who to ask if questions arise.

---

### D8: Clustering Race Condition — Atomic Check-and-Set

**Decision:** Add `@@clustering_mutex : Mutex` to `StateStore`. New method `StateStore.start_clustering_if_idle? : Bool` performs atomic check-and-set:

```crystal
def self.start_clustering_if_idle? : Bool
  @@clustering_mutex.synchronize do
    return false if @@current.clustering
    @@current = @@current.copy_with(clustering: true)
    true
  end
end
```

**Rationale:** The current TOCTOU gap between `StateStore.clustering?` (read) and `StateStore.clustering = true` (write) allows two concurrent clustering jobs to start.

**Risk:** If a crash occurs inside a clustering job after state is set to `true` but before it resets to `false`, clustering could be stuck forever. → Mitigation: Add a `start_time` field to track long-running clustering jobs as a secondary guard.

---

### D9: N+1 Query Fix — JOIN-based `entries`

**Decision:** Add `FeedRepository#find_all_with_items : Hash(String, FeedData)` using a single query with JOINs and GROUP_CONCAT for items, replacing `FeedCache#entries`.

**Rationale:** O(2N+1) queries under a mutex is the worst pattern in the hot path. SQLite handles the JOIN efficiently with the existing indexes.

**Risk:** GROUP_CONCAT on large item counts could hit SQLite's `max_length` limit (default 1MB). → Mitigation: Use a paginated approach — fetch feeds first, then items in a second query but without mutex held between them.

---

### D10: FeedCache God Object — Composition over Mixing

**Decision:** Convert `ClusteringRepository`, `HeaderColorsRepository`, `CleanupRepository` from mixins to standalone classes (`ClusteringStore`, `HeaderColorStore`, `CleanupStore`) injected into a refactored `FeedCache`:

```crystal
class FeedCache
  @clustering : ClusteringStore
  @colors : HeaderColorStore
  @cleanup : CleanupStore

  delegate :get_cluster_items_full, :assign_clusters_bulk, to: @clustering
  delegate :update_header_colors, :get_header_colors, to: @colors
end
```

**Rationale:** Mixins that carry `@mutex` and `@db` create hidden dependencies. Standalone classes with explicit constructors are testable and clearer.

**Risk:** Changing the public API of FeedCache could break consumers → Mitigation: Keep method signatures identical; only change internal structure.

---

### D11: Structured Logging — Crystal `Log` Module

**Decision:** Replace all `STDERR.puts "[prefix] message"` with `Log.for("quickheadlines.subsystem")` using `Log::Metadata` for structured fields.

**Rationale:** `STDERR.puts` has no log levels, no structured data, and can't be filtered. The Crystal `Log` module is built-in since 1.0.

**Migration:** Phase in per-subsystem loggers:
1. `Log.for("quickheadlines.storage")` for DB operations
2. `Log.for("quickheadlines.clustering")` for clustering
3. `Log.for("quickheadlines.feed")` for feed fetching
4. `Log.for("quickheadlines.http")` for HTTP/proxy operations

---

### D12: Exception Handling — Typed Rescues

**Decision:** Audit all bare `rescue` blocks. Classify into:
1. **Expected failures** (DB not found, parse error): catch specific type, return `Result.failure`
2. **Unexpected failures** (OOM, stack overflow): catch `Exception`, log with backtrace, re-raise

**Rationale:** Bare `rescue` catches `Symbol`, `Nil`, `FiberError`, and every other exception type, hiding real bugs.

---

## Risks / Trade-offs

[Risk] → [Mitigation]

**Breaking change: Admin auth now required by default** → Document in CHANGELOG; provide `ADMIN_SECRET=allow` env for emergency override during migration

**Breaking change: Image proxy only works for configured allowlist domains** → Allowlist initially contains all currently hardcoded domains + note in admin UI about extending

**Compile errors from namespace changes** → Do namespace changes in a dedicated commit with clear commit message; have backup `git stash`

**FeedCache internal API change could break tests** → Keep method signatures identical; only refactor internals

**Mutex removal from read methods is safe with SQLite WAL** → Verified: all read methods are SELECT-only; WAL mode is enabled; concurrent reads are safe in SQLite 3.7+

**Schema migration on existing databases** → All migrations use `add_column_if_not_exists` — safe to re-run on existing DBs

**Structured logging output format** → Crystal's `Log` defaults to human-readable text; configure JSON output in production if needed

**TOCTOU clustering fix with mutex** → Add `@@clustering_start_time` companion field as a watchdog for stuck clustering jobs

---

## Open Questions

1. **WS Authentication**: WebSocket connections have no auth. Should a token be required in the WS connection handshake (e.g., as a query param)?
2. **Config allowlist for proxy**: Should the image proxy allowlist be configurable via `feeds.yml` rather than hardcoded constants?
3. **Log level configuration**: Should log verbosity be configurable via `feeds.yml` (`debug: true`)?
4. **FeedCache.instance retained?** The BakedFileSystem-related code in `api.cr` uses `FeedCache.instance`. Should this be the canonical entry point, or should we introduce a proper DI container for the entire dependency graph?
5. **Admin endpoints on separate port?**: Consider running admin endpoints on a separate internal-only port/network interface to completely separate public vs. admin traffic.

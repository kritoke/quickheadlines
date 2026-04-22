## Why

The backend code review identified 20+ critical and high-priority issues across maintainability, security, performance, and error handling. The most severe are a **security flaw where admin endpoints are unauthenticated by default**, an **open SSRF proxy**, and **duplicate type definitions** that make the codebase unmaintainable. These must be addressed before public deployment.

## What Changes

### Security Fixes
- **Admin authentication enforced by default**: `ADMIN_SECRET` absent → deny instead of allow. All admin endpoints (`/api/cluster`, `/api/admin`, `/api/status`) require valid Bearer token.
- **Image proxy allowlist**: Replace private-host denylist with explicit domain allowlist. Block SSRF vectors.
- **Request body size limits**: Cap all incoming request bodies at 1MB to prevent memory exhaustion.
- **Path traversal protection**: Validate favicon hash is a 64-char hex string, validate extension against allowlist, verify resolved path stays within cache directory.
- **CSP `unsafe-inline` removal**: Use nonce-based CSP for scripts/styles since Svelte produces hashed assets.

### Maintainability Fixes
- **Canonical domain model**: Unify `Item` and `TimelineItem` types. Create `QuickHeadlines::Domain` namespace with single `FeedItem` and `TimelineEntry` structs.
- **Namespace hierarchy**: Move all top-level types under `QuickHeadlines::` namespaces (`QuickHeadlines::Storage`, `QuickHeadlines::State`, `QuickHeadlines::Domain`).
- **Dual migration system eliminated**: Remove ad-hoc `add_column_if_missing` from `DatabaseService#create_schema`. Use only the versioned `run_migrations` system.
- **Dead code removed**: `DatabaseService#get_timeline_items`, `FeedState` state machine, `StoryGroup`, `ClusteredTimelineItem`, `StateStore#feeds_for_tab_impl`, `StateStore#all_timeline_items_impl`, `ClusteringEngine#find_similar_for_item`.
- **Tuple explosion resolved**: Replace anonymous 14-field tuples in repository return types with named structs.
- **Inconsistent DI resolved**: Choose ADI-based dependency injection throughout; remove `@@instance` singleton pattern from `DatabaseService` and `FeedCache` (keep `FeedCache.instance` for BakedFileSystem compat only).

### Performance Fixes
- **N+1 query elimination**: Replace `FeedCache#entries` (2N+1 queries) with a single JOIN query via `FeedRepository#find_all_with_items`.
- **Redundant sort removed**: `Api.feed_to_response` sorts items on every request despite items already being stored sorted. Remove the O(n log n) sort.
- **Mutex contention reduced**: Remove `@mutex.synchronize` from read-only methods in `ClusteringRepository` (SQLite WAL supports concurrent reads). Keep mutex only for writes.
- **Streaming proxy response**: Replace full-body buffering with streaming + early size check in image proxy.

### Error Handling Fixes
- **No more bare `rescue`**: Replace all bare `rescue` blocks with typed `rescue ex : Exception` or `rescue ex : DB::Error`. Re-raise unexpected exceptions.
- **Race condition fixed**: Make `StateStore.clustering?` check-and-set atomic with a dedicated `@@clustering_mutex`.
- **Structured logging adopted**: Replace all `STDERR.puts` with `Log` module (`Log.for("quickheadlines")`). Consistent format: `{context} {message}` with named fields.

### Architecture Fixes
- **FeedCache god object split**: Separate `ClusteringRepository`, `HeaderColorsRepository`, and `CleanupRepository` mixins into standalone classes (`ClusteringStore`, `HeaderColorStore`, `CleanupStore`) composed into a `CacheBackend` facade.
- **Controllers refactored**: Split `FeedsController` into `FeedsController`, `ConfigController`, `TabsController`, `HeaderColorController`.

## Capabilities

### New Capabilities

- `security-admin-auth`: Enforced admin authentication on all sensitive endpoints. Bearer token required; unauthenticated requests receive 401.
- `security-proxy-allowlist`: Image proxy restricts requests to an explicit allowlist of external domains. All other targets rejected with 403.
- `security-request-limits`: All API endpoints enforce a 1MB request body size limit. Requests exceeding this receive a 413.
- `security-path-traversal`: Favicon file serving validates hash format (64-char hex) and extension (known types only) before file access.
- `data-canonical-domain-model`: Single `FeedItem` type replaces duplicate `Item` definitions. Single `TimelineEntry` replaces duplicate `TimelineItem` structs.
- `data-namespace-hierarchy`: All types moved under `QuickHeadlines::` namespace hierarchy.
- `perf-feed-entries-query`: `FeedCache#entries` uses a single JOIN query instead of N+1.
- `perf-mutex-read-optimization`: Clustering repository read methods run lock-free; only writes are synchronized.
- `error-structured-logging`: Application uses `Log` module with context-aware structured logs instead of `STDERR.puts`.
- `arch-feedcache-split`: FeedCache split into focused `ClusteringStore`, `HeaderColorStore`, and `CleanupStore` classes.
- `arch-controller-split`: `FeedsController` split into domain-focused controllers.
- `state-atomic-clustering`: Clustering state transitions are atomic (no TOCTOU race condition).

### Modified Capabilities
- *(none — no existing specs to modify)*

## Impact

### Affected Code
- `src/controllers/api_base_controller.cr` — Admin auth, rate limiter use
- `src/controllers/feeds_controller.cr` — Split into multiple controllers
- `src/controllers/admin_controller.cr` — Auth required, body limits
- `src/controllers/proxy_controller.cr` — SSRF protection, streaming response
- `src/controllers/static_controller.cr` — CSP hardening
- `src/storage/feed_cache.cr` — God object split
- `src/storage/database.cr` — Remove dual migration system
- `src/storage/clustering_repo.cr` — Named structs, mutex read optimization
- `src/storage/cleanup.cr` — Structured logging, streaming
- `src/storage/header_colors.cr` — Structured logging
- `src/services/database_service.cr` — Remove dead code, cleanup
- `src/services/clustering_service.cr` — Atomic state
- `src/models.cr` — Domain types, namespace, dead code removal
- `src/constants.cr` — May add new limit constants
- `src/utils.cr` — May add request size limit helper
- `src/api.cr` — Remove redundant sort

### New Files
- `src/domain/` — New namespace directory for canonical domain models
- `src/storage/clustering_store.cr` — Extracted from clustering_repo.cr
- `src/storage/header_color_store.cr` — Extracted from header_colors.cr
- `src/storage/cleanup_store.cr` — Extracted from cleanup.cr

### Removed Files
- *(none — files refactored in place, no files deleted in this change)*

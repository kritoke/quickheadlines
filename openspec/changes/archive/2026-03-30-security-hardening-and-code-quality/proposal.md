## Why

The backend has accumulated several security, reliability, and maintainability issues that need addressing before the project matures further. These include unauthenticated endpoints that perform expensive operations, thread-safety issues in favicon syncing, unsafe schema migration patterns, and scattered duplicate code. This change hardens the backend against abuse, improves production reliability, and reduces long-term maintenance burden.

## What Changes

### Security Hardening
- **Add `ADMIN_SECRET` environment variable authentication** to `/api/admin` and `/api/cluster` endpoints. Requests must include `Authorization: Bearer <token>` header matching the env var value. Unauthenticated requests receive `401 Unauthorized`. This is opt-in — if the env var is not set, endpoints remain open (preserving self-hosted single-binary model).
- **Add client-IP-aware rate limiting** to `/api/cluster` and `/api/admin` instead of global shared keys. Use `X-Forwarded-For` when behind a reverse proxy (controlled by `TRUSTED_PROXY` env var).
- **Remove dead `action` code path** in `admin` endpoint — `action = "cleanup-orphaned"` was hardcoded, making the clear-cache path unreachable.
- **Validate `repo_path` format** in `fetch_config_from_github` to prevent path traversal.

### Thread Safety & Reliability
- **Narrow mutex scope in `sync_favicon_paths`** — move all heavy operations (DB queries, file I/O, HTTP fetches, color extraction) outside the mutex. Mutex only protects the atomic check-and-write.
- **Add schema version table** for migrations instead of bare `begin/rescue` around `ALTER TABLE`. Each migration runs exactly once, and failed migrations are logged with context.
- **Add atomic counters** to `HealthMonitor` for `cache_hits`, `cache_misses`, `db_query_times` — use `Atomic(Int64)` instead of bare `Int64` with `+=`.

### Code Quality
- **Create canonical `UrlNormalizer` module** — single `normalize_url` implementation used by all call sites. Remove duplicates from `feed_fetcher.cr`, `api_controller.cr`, and `cache_utils.cr`.
- **Move global functions into classes** — `fetch_feed`, `refresh_all`, `error_feed_data`, `load_feeds_from_cache` become methods on `FeedService`. `start_refresh_loop` stays as a module function since it needs to run at startup.
- **Exponential backoff** in feed fetching — replace `5 * retries` with `2 ** retries` (capped at 60s) for better tolerance of transient failures.
- **Add magic number constants** — `MAX_PROXY_IMAGE_BYTES`, `MAX_CONNECTIONS`, `STALE_CONNECTION_AGE`, `CONNECTION_QUEUE_SIZE` etc. move to `constants.cr`.

## Capabilities

### New Capabilities

- `endpoint-auth`: Bearer-token authentication for sensitive endpoints. If `ADMIN_SECRET` env var is set, `/api/admin` and `/api/cluster` require `Authorization: Bearer <value>` header. If unset, endpoints remain open (backward-compatible for self-hosted).
- `ip-aware-rate-limiting`: Replace global shared rate limiter keys with client-IP-derived keys. Extract IP from `X-Forwarded-For` when `TRUSTED_PROXY` env var is set, falling back to `remote_address`.
- `favicon-sync-thread-safety`: Refactor `sync_favicon_paths` to hold mutex only during the critical section (check-if-exists + write). All I/O, DB operations, and external fetches happen outside the lock.
- `schema-version-migration`: Replace `ALTER TABLE ... rescue` pattern with a `schema_version` table. Migrations are numbered, idempotent, and logged. Failed migrations surface clear error messages instead of silent swallows.
- `url-normalization-canonical`: Single `UrlNormalizer` module with one `normalize` method used project-wide. Removes three divergent implementations with subtly different stripping logic.
- `exponential-backoff`: Replace linear backoff (`5 * retries`) with exponential backoff (`min(60, 2 ** retries)` seconds) in feed fetching retry logic.
- `atomic-health-metrics`: Use `Atomic(Int64)` for `cache_hits`, `cache_misses`, `db_query_count` in `HealthMonitor`, eliminating race conditions in M:N fiber model.
- `admin-action-fix`: Remove unreachable `action = "cleanup-orphaned"` dead code; make the action selectable via request body `{"action": "clear-cache"|"cleanup-orphaned"}`.

### Modified Capabilities

- `rate-limiter-memory-safety` (existing): Extend to support IP-derived keys and configurable key generation. The current spec requires cleanup but does not specify per-IP isolation.

## Impact

- **API Changes**: `/api/admin` and `/api/cluster` require `Authorization` header when `ADMIN_SECRET` is set. `/api/cluster` rate limiting changes from global to per-IP.
- **New Dependencies**: None — uses existing Crystal stdlib (`Atomic`, `Mutex`).
- **Configuration**: Two new optional env vars: `ADMIN_SECRET` (bearer token) and `TRUSTED_PROXY` (enable X-Forwarded-For parsing).
- **Backward Compatibility**: Auth is opt-in. If `ADMIN_SECRET` is not set, behavior is unchanged. Rate limiter falls back to global key when IP extraction fails.
- **Files Modified**:
  - `src/api_controller.cr` — auth, rate limit keys, admin action fix
  - `src/rate_limiter.cr` — IP-aware key generation
  - `src/storage/feed_cache.cr` — mutex scope, schema version
  - `src/storage/database.cr` — migration pattern
  - `src/health_monitor.cr` — atomic counters
  - `src/fetcher/feed_fetcher.cr` — exponential backoff, move global functions
  - `src/services/feed_service.cr` — encapsulate global functions
  - `src/utils.cr` — UrlNormalizer module
  - `src/constants.cr` — magic numbers

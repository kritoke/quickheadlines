## Context

QuickHeadlines is a self-hosted single-binary RSS/Reddit feed aggregator with a Svelte SPA frontend. The backend is a Crystal application using Athena Framework, backed by SQLite. It has no built-in authentication since it targets single-user/self-hosted deployments. However, several endpoints perform expensive or destructive operations (`/api/cluster` triggers MinHash computation on thousands of items; `/api/admin` can clear the entire cache). These are currently unauthenticated and use global rate-limit keys.

The codebase also has accumulated technical debt: 40+ global `def` statements, three divergent `normalize_url` implementations, a favicon sync that holds a mutex for minutes during external HTTP fetches, and health monitoring with non-atomic counters.

## Goals / Non-Goals

**Goals:**
- Add optional bearer-token auth for sensitive endpoints (opt-in via `ADMIN_SECRET` env var)
- Fix thread-safety issues in favicon syncing and health monitoring
- Replace silent-exception schema migrations with versioned, logged migrations
- Consolidate duplicate `normalize_url` into a single canonical implementation
- Replace linear backoff with exponential for feed fetching retries
- Add IP-aware rate limiting (configurable via `TRUSTED_PROXY` env var)

**Non-Goals:**
- Full user authentication system (out of scope for self-hosted single-binary model)
- Moving all global functions to classes (only the most problematic ones)
- Performance optimization beyond the identified critical bottlenecks
- Changing the frontend Elm architecture

## Decisions

### 1. Opt-in Bearer Token Auth (vs. always-on auth)

**Decision**: Auth is enabled only when `ADMIN_SECRET` env var is set. If unset, behavior is unchanged (backward-compatible).

**Rationale**: The user explicitly stated this is a self-hosted single-binary app without built-in auth. Forcing auth on would break existing deployments. Making it opt-in via env var is zero-config for existing users while allowing security-conscious operators to enable it with a single environment variable.

**Alternative considered**: Require auth always, with a config-file-generated token. Rejected because it changes the deployment model for all existing users.

**Implementation**:
```crystal
# api_controller.cr
private def check_admin_auth(request : ATH::Request) : Bool
  return true if ENV["ADMIN_SECRET"]?.nil?
  token = request.headers["Authorization"]?
  token == "Bearer #{ENV["ADMIN_SECRET"]}"
end
```

---

### 2. IP-Aware Rate Limiting with X-Forwarded-For Support (vs. global keys)

**Decision**: Extract client IP from request, falling back to `remote_address`. Support `X-Forwarded-For` when `TRUSTED_PROXY` env var is set.

**Rationale**: Currently `/api/cluster` and `/api/admin` use global shared keys (`"cluster_endpoint"`, `"admin_endpoint"`), meaning one abuser rate-limits the entire world. Per-IP keys solve this. `X-Forwarded-For` support is needed because most self-hosted deployments run behind nginx/Caddy reverse proxies.

**Implementation**:
```crystal
# Extract client IP for rate limiting
private def client_ip(request : ATH::Request) : String
  if ENV["TRUSTED_PROXY"]? && (xff = request.headers["X-Forwarded-For"]?)
    xff.split(",").first?.try(&.strip) || request.remote_address.to_s
  else
    request.remote_address.to_s
  end
end
```

**Trade-off**: `X-Forwarded-For` can be spoofed if `TRUSTED_PROXY` is set incorrectly. The env var serves as an explicit acknowledgment of this risk.

---

### 3. Mutex Scope Narrowing in `sync_favicon_paths` (vs. async approach)

**Decision**: Keep mutex but narrow it to only protect the file write. All DB queries, HTTP fetches, and color extraction happen before acquiring the lock.

**Rationale**: The current code holds `@mutex` (which blocks all other `FeedCache` operations) while doing N external HTTP fetches and color extractions. The lock should only protect the check-and-write to the filesystem. Using async/fiber-based concurrency for external fetches was considered but adds complexity; narrowing the mutex scope is a simpler, targeted fix.

**Implementation pattern**:
```crystal
# Before: mutex held during everything
# After:
fees_data.each do |...|
  # All heavy work OUTSIDE mutex
  extracted = ColorExtractor.theme_aware_extract_from_favicon(...)
  local_path = FaviconStorage.fetch_and_save(...)

  # Mutex ONLY for atomic write
  @mutex.synchronize do
    @db.exec("UPDATE ...") unless File.exists?(filepath)
  end
end
```

---

### 4. Schema Version Table (vs. ALTER TABLE rescue pattern)

**Decision**: Introduce a `schema_info` table with a single `version : Int32` row. Migrations are numbered functions that run sequentially.

**Rationale**: The current `begin; ALTER TABLE ...; rescue; end` pattern silently swallows ALL exceptions, including disk-full and corruption errors that should abort startup. A version table lets us track exactly which migrations ran, run each exactly once, and log failures with context.

**Migration table schema**:
```sql
CREATE TABLE IF NOT EXISTS schema_info (version INTEGER PRIMARY KEY);
INSERT OR IGNORE INTO schema_info (version) VALUES (0);
```

**Migration registry** (in `database.cr`):
```crystal
struct DatabaseMigration
  property version : Int32
  property name : String
  property up : DB::Database -> Nil
end

MIGRATIONS = [
  DatabaseMigration.new(version: 1, name: "add_favicon_data_column") { |db| db.exec("ALTER TABLE feeds ADD COLUMN favicon_data TEXT") },
  # ...
]

def run_migrations(db : DB::Database)
  current_version = db.query_one("SELECT version FROM schema_info", as: Int32)
  MIGRATIONS.each do |m|
    next if m.version <= current_version
    db.exec("ALTER TABLE ...") # raises on failure, logged
    db.exec("UPDATE schema_info SET version = ?", m.version)
  end
end
```

---

### 5. Atomic Counters in HealthMonitor (vs. fiber-safe primitives)

**Decision**: Use Crystal's `Atomic(Int64)` for all counter fields in `HealthMonitor`.

**Rationale**: Crystal's M:N threading model (spray.hn: scheduler) means `@@cache_hits += 1` is not atomic. `Atomic(Int64)` provides lock-free atomic operations via compiler intrinsics on supported platforms.

**Alternative considered**: Use a `Mutex` around counter access. `Atomic` is faster and simpler for single-value counters.

---

### 6. Canonical `UrlNormalizer` Module (vs. class)

**Decision**: Create a `UrlNormalizer` module with class methods, replacing three divergent implementations.

**Rationale**: Three `normalize_url` implementations exist with subtly different behavior:
- `cache_utils.cr`: uses `rchop` and adds trailing `/`
- `feed_fetcher.cr`: uses `sub` to strip `www.` prefix only, no trailing slash handling
- `api_controller.cr`: uses `strip` + `rstrip('/')` + regex replacements

These differences cause bugs where the same URL normalized differently in different places, breaking cache lookups. A single canonical implementation fixes this.

---

### 7. Exponential Backoff (vs. fixed/larger intervals)

**Decision**: Replace `5 * retries` with `min(60, 2 ** retries)` seconds.

**Rationale**: Linear backoff wastes time on transient failures. For a system refreshing hundreds of feeds, exponential backoff with a 60s cap provides faster recovery without hammering failing feeds.

---

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| `X-Forwarded-For` spoofing if `TRUSTED_PROXY` misconfigured | Env var is explicit opt-in; documentation warns against setting it unless behind a trusted reverse proxy |
| Schema migration failures if DB is locked or disk full | Migration function is wrapped in logging; startup continues with warning but DB is not corrupted further |
| Backward compat: existing deployments with no `ADMIN_SECRET` remain fully open | Explicitly documented; operator must set env var to enable |
| Narrowed mutex in favicon sync still serializes writes, but reads are now concurrent | Acceptable — write-heavy workloads are rare; read concurrency is the common case |
| `Atomic(Int64)` not available on all platforms | Crystal 1.18.2 has `Atomic` on all platforms supported (Linux, FreeBSD, macOS); documented as requiring Crystal 1.18+ |

---

## Open Questions

1. Should `TRUSTED_PROXY` accept a specific IP/CIDR range, or be a boolean flag? A boolean is simpler; a CIDR allows more granular trust. Defer to boolean for now.
2. The `admin` endpoint `action` field — should we support both `clear-cache` and `cleanup-orphaned` via request body, or just one active operation? Request body is fine since it's already JSON-parsed.
3. Should we add a `LOGIN` endpoint for the SPA that sets a session cookie, or is bearer token sufficient? Bearer token is sufficient for self-hosted — SPA can prompt for token on first load.

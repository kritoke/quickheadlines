## 1. Schema Version Migration

- [ ] 1.1 Create `SchemaMigration` struct in `src/storage/database.cr` with `version : Int32`, `name : String`, and `up : DB::Database -> Nil` fields
- [ ] 1.2 Add `MIGRATIONS` constant array with all existing schema operations (favicon_data, header_text_color, header_theme_colors, minhash_signature, cluster_id, lsh_bands text migration, unique index)
- [ ] 1.3 Add `schema_info` table creation to `create_schema` with `CREATE TABLE IF NOT EXISTS schema_info (version INTEGER PRIMARY KEY)`
- [ ] 1.4 Implement `run_migrations(db)` function that reads current version and applies pending migrations in order
- [ ] 1.5 Replace bare `begin/rescue ALTER TABLE` blocks with migration-driven approach
- [ ] 1.6 Add migration logging to stderr: `"[Schema] Running migration N: <name>"` and `"[Schema] Migration N applied"`
- [ ] 1.7 Verify `just nix-build` succeeds

## 2. Bearer Token Auth for Endpoints

- [ ] 2.1 Add `check_admin_auth(request : ATH::Request) : Bool` private method to `ApiController`
- [ ] 2.2 Implement `ADMIN_SECRET` env var check in `check_admin_auth` — return `true` if env var is nil or empty
- [ ] 2.3 Add `Authorization: Bearer <token>` header validation in `check_admin_auth`
- [ ] 2.4 Add auth check to `cluster` endpoint before spawning clustering job; return `401 Unauthorized` with JSON body if auth fails
- [ ] 2.5 Add auth check to `admin` endpoint before spawning admin job; return `401 Unauthorized` with JSON body if auth fails
- [ ] 2.6 Update tests or add new spec tests for auth behavior
- [ ] 2.7 Verify `just nix-build` succeeds

## 3. IP-Aware Rate Limiting

- [ ] 3.1 Add `client_ip(request : ATH::Request) : String` private method to `ApiController`
- [ ] 3.2 Implement `X-Forwarded-For` parsing when `TRUSTED_PROXY` env var is set, fall back to `request.remote_address`
- [ ] 3.3 Update `RateLimiter.get_or_create` call in `cluster` endpoint to use `client_ip` as key instead of `"cluster_endpoint"`
- [ ] 3.4 Update `RateLimiter.get_or_create` call in `admin` endpoint to use `client_ip` as key instead of `"admin_endpoint"`
- [ ] 3.5 Verify `just nix-build` succeeds

## 4. Admin Action Fix

- [ ] 4.1 Parse `action` field from request body JSON in `admin` endpoint instead of hardcoding `action = "cleanup-orphaned"`
- [ ] 4.2 Implement case statement handling `"clear-cache"` and `"cleanup-orphaned"` actions
- [ ] 4.3 Return `400 Bad Request` with `"Unknown action"` for unrecognized action values
- [ ] 4.4 Return `400 Bad Request` with `"Missing action field"` when action is absent from request body
- [ ] 4.5 Verify `just nix-build` succeeds

## 5. Favicon Sync Thread Safety

- [ ] 5.1 Refactor `sync_favicon_paths` in `src/storage/feed_cache.cr` — move all DB queries, HTTP fetches, and color extraction outside `@mutex.synchronize` block
- [ ] 5.2 Mutex only guards the final filesystem write (`File.write` / `File.exists?` check)
- [ ] 5.3 Pre-compute all values needed for each iteration before acquiring lock
- [ ] 5.4 Ensure `@db.exec` calls happen before mutex, not inside
- [ ] 5.5 Verify `just nix-build` succeeds

## 6. Atomic Health Monitor Counters

- [ ] 6.1 Change `@@cache_hits` in `HealthMonitor` from `Int32` to `Atomic(Int64)`
- [ ] 6.2 Change `@@cache_misses` in `HealthMonitor` from `Int32` to `Atomic(Int64)`
- [ ] 6.3 Change `@@db_query_count` in `HealthMonitor` from `Int32` to `Atomic(Int64)`
- [ ] 6.4 Update `record_cache_hit` to use `@@cache_hits.add(1)` instead of `@@cache_hits += 1`
- [ ] 6.5 Update `record_cache_miss` to use `@@cache_misses.add(1)`
- [ ] 6.6 Update `record_db_query` to use `@@db_query_count.add(1)`
- [ ] 6.7 Keep `@@db_query_times` as `Array(Float64)` with manual ring buffer (already safe with mutex pattern)
- [ ] 6.8 Verify `just nix-build` succeeds

## 7. Canonical UrlNormalizer

- [ ] 7.1 Create `UrlNormalizer` module in `src/utils.cr` with `normalize(url : String) : String` method
- [ ] 7.2 Implement canonical logic: strip trailing `/`, remove `/rss`, `/feed`, `/atom` suffixes, strip `www.` prefix, upgrade `http://` to `https://`
- [ ] 7.3 Update `cache_utils.cr:normalize_feed_url` to delegate to `UrlNormalizer.normalize`
- [ ] 7.4 Update `feed_fetcher.cr:normalize_url` to delegate to `UrlNormalizer.normalize`
- [ ] 7.5 Update `api_controller.cr:normalize_url` to delegate to `UrlNormalizer.normalize`
- [ ] 7.6 Verify only `UrlNormalizer.normalize` exists (grep check)
- [ ] 7.7 Verify `just nix-build` succeeds

## 8. Exponential Backoff

- [ ] 8.1 Replace `calculate_backoff` in `src/fetcher/feed_fetcher.cr` from `5 * retries` to `Math.min(60, 2 ** retries)`
- [ ] 8.2 Keep `handle_timeout_error` and `handle_server_error` using `calculate_backoff`
- [ ] 8.3 Verify logic with a test case for backoff values at retries 0 through 7
- [ ] 8.4 Verify `just nix-build` succeeds

## 9. Magic Number Constants

- [ ] 9.1 Add `HTTP_CONNECT_TIMEOUT` constant (10 seconds)
- [ ] 9.2 Add `HTTP_READ_TIMEOUT` constant (30 seconds)
- [ ] 9.3 Add `FETCH_TIMEOUT_SECONDS` constant (60 seconds)
- [ ] 9.4 Add `MAX_REDIRECTS` constant (10)
- [ ] 9.5 Add `MAX_RETRIES` constant (3)
- [ ] 9.6 Add `MAX_PROXY_IMAGE_BYTES` constant (5 * 1024 * 1024)
- [ ] 9.7 Add `MAX_CONNECTIONS` constant (1000)
- [ ] 9.8 Add `MAX_CONNECTIONS_PER_IP` constant (10)
- [ ] 9.9 Add `STALE_CONNECTION_AGE_SECONDS` constant (120)
- [ ] 9.10 Add `CONNECTION_QUEUE_SIZE` constant (100)
- [ ] 9.11 Update all call sites to use constants instead of inline values
- [ ] 9.12 Verify `just nix-build` succeeds

## 10. Repo Path Validation

- [ ] 10.1 Add validation in `fetch_config_from_github` to ensure `repo_path` matches `^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$`
- [ ] 10.2 Return `nil` early if validation fails (don't construct URL)
- [ ] 10.3 Log warning when invalid repo_path is detected
- [ ] 10.4 Verify `just nix-build` succeeds

## 11. Final Verification

- [ ] 11.1 Run `nix develop . --command crystal spec` and ensure all tests pass
- [ ] 11.2 Run `cd frontend && npm run test` if frontend tests exist
- [ ] 11.3 Run `nix develop . --command ameba --fix` to auto-fix any style issues
- [ ] 11.4 Verify `just nix-build` succeeds (final build check)

## Why

A comprehensive code review identified several critical issues requiring fixes:

1. **Favicon path bug**: Fresh Docker/FreeBSD instances show missing favicons because `FaviconStorage` uses relative paths (`public/favicons/`) instead of absolute paths based on cache directory, causing writes and reads to mismatch when CWD differs.

2. **Security issues**: Error messages leak internal details to HTTP clients via `ex.message` exposure. SQL construction uses string interpolation instead of parameterized queries.

3. **Performance problems**: N+1 query pattern in timeline API (300 queries for 100 items). Unbounded memory caches that grow forever.

4. **Code quality**: Duplicate SSRF validation logic across files. Magic numbers not using defined constants. Bare `rescue` blocks silently swallowing exceptions.

5. **Incomplete features**: Heat map service and repository have unimplemented TODOs.

These issues affect reliability, security, and maintainability in production deployments.

## What Changes

1. **Favicon Storage Path Fix**
   - Change `FaviconStorage::FAVICON_DIR` from relative to absolute path computed from cache directory
   - Ensure `FaviconStorage.init` is called before HTTP server starts
   - Add fallback initialization on first favicon save attempt

2. **Security Hardening**
   - Replace `ex.message` error responses with generic "Internal server error" in `StaticController`
   - Add DNS resolution validation to SSRF checks in `validate_proxy_url`
   - Replace string-interpolated SQL with parameterized queries in `CleanupRepository`

3. **Performance Improvements**
   - Batch fetch cluster data in timeline API to eliminate N+1 queries
   - Add LRU eviction to `ColorExtractor.extraction_cache` with configurable max size
   - Add cleanup for orphaned `HealthMonitor` entries when feeds are removed

4. **Code Quality**
   - Extract duplicate URL/SSRF validation to shared `Utils.validate_proxy_url` method
   - Replace magic numbers with constants from `Constants` module
   - Replace bare `rescue` blocks with structured error handling that logs properly

5. **Remove Incomplete Code**
   - Remove unimplemented heat map service/repository stubs if not being completed

## Capabilities

### New Capabilities
- `favicon-path-resolution`: Favicon storage path resolution using absolute paths based on cache directory, ensuring consistent behavior across Docker/FreeBSD/Linux environments

### Modified Capabilities
- None - all changes are implementation details within existing capabilities

## Impact

- **Backend**: `src/favicon_storage.cr`, `src/web/static_controller.cr`, `src/controllers/api_controller.cr`, `src/storage/cleanup.cr`, `src/api.cr`, `src/color_extractor.cr`, `src/health_monitor.cr`, `src/utils.cr`

- **No API changes**: All modifications are internal to existing behavior

- **No breaking changes**: Existing functionality preserved, only bugs fixed

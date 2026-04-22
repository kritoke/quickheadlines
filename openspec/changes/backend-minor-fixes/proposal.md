## Why

Several small bugs and code quality issues don't warrant their own changes but should be cleaned up: a `.woff` MIME type typo maps to the wrong value, `rescue Exception` in auth checking is too broad and swallows programming errors, `rescue nil` patterns silently discard errors with no logging, admin request parsing silently drops malformed input, HTTP timeouts are scattered across files instead of using centralized constants, and duplicate IP extraction logic produces different results for WebSocket vs HTTP clients.

## What Changes

- Fix `.woff` MIME type from `font/woff2` to `font/woff` in `utils.cr`
- Narrow `rescue Exception` in `check_admin_auth` to `rescue ArgumentError`
- Replace `rescue nil` in `AppBootstrap#close` with logged rescue
- Add logging to `AdminController#parse_admin_action` rescue blocks
- Use `Constants` values for HTTP timeouts in favicon/proxy code
- Consolidate IP extraction: WebSocket handler uses the same `TRUSTED_PROXY`-aware logic as `ApiBaseController.client_ip`

## Capabilities

### New Capabilities
- `backend-minor-fixes`: Small bug fixes and code quality improvements across utils, auth, logging, timeouts, and IP extraction

### Modified Capabilities

## Impact

- **Utils**: `utils.cr` (MIME fix, IP extraction consolidation)
- **Controllers**: `api_base_controller.cr` (narrow rescue), `admin_controller.cr` (add logging)
- **Services**: `app_bootstrap.cr` (logged rescue)
- **Storage**: `favicon_storage.cr` (use Constants for timeouts)
- **Controllers**: `proxy_controller.cr` (use Constants for timeouts)
- **Entry point**: `quickheadlines.cr` (use shared IP extraction)

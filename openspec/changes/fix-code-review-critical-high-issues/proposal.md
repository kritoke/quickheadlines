## Why

A comprehensive code review identified 9 critical and high severity security, stability, and correctness issues that must be fixed before production deployment. These include XSS vulnerabilities, CSS injection, SSRF, IP spoofing, timing attacks, memory leaks, and missing rate limiting. Fixing these now prevents security incidents and production outages.

## What Changes

- **CRITICAL**: Sanitize all `href` attributes in `TimelineView.svelte` and `ClusterExpansion.svelte` using `sanitizeUrl()` to prevent `javascript:` URI XSS attacks from malicious RSS feeds
- **CRITICAL**: Sanitize CSS color values in `feedItem.ts`'s `getHeaderStyle()` using `sanitizeCssColor()` to prevent CSS injection
- **CRITICAL**: Add private IP/reserved host validation to `FaviconStorage.fetch_and_save()` redirect following to prevent SSRF attacks
- **CRITICAL**: Remove `XML::ParserOptions::NOENT` from feed parser to prevent XML entity expansion attacks
- **HIGH**: Fix X-Forwarded-For spoofing in `client_ip()` — take first (leftmost) IP instead of last when behind trusted proxy
- **HIGH**: Fix timing-safe compare to not leak secret length via early rejection on byte size mismatch
- **HIGH**: Add cleanup function call for timeline effects on component unmount to prevent memory leak
- **HIGH**: Add rate limiting to `/api/feeds` and `/api/timeline` endpoints
- **HIGH**: Remove duplicate WebSocket listener registration in feed page that causes double-fetch on updates

## Capabilities

### New Capabilities
- `input-sanitization`: Centralized input sanitization for URL and CSS color values across the frontend. All user-facing links and style values must pass through `sanitizeUrl()` and `sanitizeCssColor()` respectively before rendering. Existing `validation.ts` utilities are extended to cover all cases found in the codebase.
- `ssrf-protection`: Server-side request forgery protection for all HTTP redirects followed by the application. Favicon fetching and any other redirect-following HTTP clients must validate final destination hosts against private/reserved IP ranges before making connections.
- `api-rate-limiting`: Rate limiting on public API endpoints that were previously unprotected. `/api/feeds` and `/api/timeline` now use the existing `RateLimiter` infrastructure to limit requests per client IP.
- `timeline-effect-cleanup`: Proper lifecycle management for Svelte effects that set up intervals and WebSocket listeners. All effects must clean up on component unmount to prevent memory leaks during SPA navigation.

### Modified Capabilities
- `trusted-proxy-validation`: The existing proxy/IP extraction logic in `api_base_controller.cr` is corrected to take the first IP from X-Forwarded-For (leftmost, the original client) when behind a trusted proxy, not the last IP. Also fixes the timing-safe compare to not leak secret length.

## Impact

### Backend (Crystal)
- `src/controllers/api_base_controller.cr`: Fix `client_ip()` X-Forwarded-For handling and `timing_safe_compare` length leak
- `src/favicon_storage.cr`: Add SSRF protection to `fetch_and_save()` redirect following
- `src/parser.cr`: Remove `NOENT` XML parser option
- `src/controllers/feeds_controller.cr`: Add rate limiting
- `src/controllers/timeline_controller.cr`: Add rate limiting

### Frontend (Svelte/TypeScript)
- `frontend/src/lib/components/TimelineView.svelte`: Sanitize `item.link` with `sanitizeUrl()`
- `frontend/src/lib/components/ClusterExpansion.svelte`: Sanitize `item.link` with `sanitizeUrl()`
- `frontend/src/lib/utils/feedItem.ts`: Sanitize CSS colors in `getHeaderStyle()`
- `frontend/src/routes/timeline/+page.svelte`: Add cleanup for timeline effects, remove dead listener
- `frontend/src/routes/+page.svelte`: Remove duplicate WebSocket listener
- `frontend/src/lib/stores/feedStore.svelte.ts`: Add error logging for silent config failures
- `frontend/src/lib/stores/timelineStore.svelte.ts`: Add error logging for silent config failures

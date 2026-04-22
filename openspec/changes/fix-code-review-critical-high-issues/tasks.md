## 1. Frontend: Fix XSS in TimelineView

- [x] 1.1 Import `sanitizeUrl` in `TimelineView.svelte`
- [x] 1.2 Replace `href={item.link}` with `href={sanitizeUrl(item.link)}` on line ~166
- [x] 1.3 Verify `ClusterExpansion.svelte` link rendering uses sanitization

## 2. Frontend: Fix CSS Injection in feedItem.ts

- [x] 2.1 Import `sanitizeCssColor` in `feedItem.ts`
- [x] 2.2 Update `getHeaderStyle()` to sanitize `colors.bg` and `colors.text` with `sanitizeCssColor()`
- [x] 2.3 Add fallback value `#64748b` for bg and `#ffffff` for text

## 3. Frontend: Fix ClusterExpansion XSS

- [x] 3.1 Import `sanitizeUrl` in `ClusterExpansion.svelte`
- [x] 3.2 Replace `href={item.link}` with `href={sanitizeUrl(item.link)}` on line ~30

## 4. Backend: Fix SSRF in FaviconStorage

- [x] 4.1 Add private host check to `fetch_and_save()` in `src/favicon_storage.cr`
- [x] 4.2 Validate final resolved URI host before making HTTP connection
- [x] 4.3 Reject and return nil if host is private/reserved per `Utils.private_host?()`

## 5. Backend: Remove NOENT XML Parser Option

- [x] 5.1 Remove `XML::ParserOptions::NOENT` from `XML.parse()` call in `src/parser.cr`
- [x] 5.2 Keep `XML::ParserOptions::RECOVER` for malformed XML tolerance
- [x] 5.3 Verify HTML entity unescaping for titles still works via `HTML.unescape()`

## 6. Backend: Fix X-Forwarded-For IP Spoofing

- [x] 6.1 Change `xff.split(",").last?.try(&.strip)` to `.first?.try(&.strip)` in `api_base_controller.cr`
- [x] 6.2 Document the change in code comment explaining first IP is original client

## 7. Backend: Fix Timing-Safe Compare Length Leak

- [x] 7.1 Modify `timing_safe_compare()` in `api_base_controller.cr` to compare all bytes
- [x] 7.2 Pad shorter string with null bytes to match longer string length before comparison
- [x] 7.3 Ensure no early return on byte size mismatch

## 8. Backend: Add Rate Limiting to /api/feeds

- [x] 8.1 Add `RateLimiter` check to `feeds()` method in `feeds_controller.cr`
- [x] 8.2 Use key format `api_feeds:{ip}` with 60 req/min limit
- [x] 8.3 Return 429 with `Retry-After` header when rate limited

## 9. Backend: Add Rate Limiting to /api/timeline

- [x] 9.1 Add `RateLimiter` check to `timeline()` method in `timeline_controller.cr`
- [x] 9.2 Use key format `api_timeline:{ip}` with 60 req/min limit
- [x] 9.3 Return 429 with `Retry-After` header when rate limited

## 10. Frontend: Fix Timeline Memory Leak

- [x] 10.1 Modify `timeline/+page.svelte` to return cleanup function from `$effect`
- [x] 10.2 Call `timelineEffects.stop()` in the cleanup function
- [x] 10.3 Remove dead `visibilitychange` listener registration on line ~90

## 11. Frontend: Fix Double WebSocket Listener

- [x] 11.1 Remove inline `websocketConnection.addEventListener(handleWebSocketMessage)` from `+page.svelte`
- [x] 11.2 Use `createFeedEffects().start()` for proper WebSocket handling
- [x] 11.3 Removed unused `websocketConnection` import, cleanup now properly calls `feedEffects.stop()`

## 12. Verification

- [x] 12.1 Run `just nix-build` to verify Crystal compiles
- [x] 12.2 Run `nix develop . --command crystal spec` for backend tests - 216 examples, 0 failures
- [x] 12.3 Run `cd frontend && npm run test` for frontend tests - 25 tests passed
- [x] 12.4 All changed files reviewed for issues

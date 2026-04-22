## Why

The QuickHeadlines application has two critical issues that degrade user experience and security:

1. **Tab state is lost when switching between views** — When users navigate from the feed view (/) to the timeline view (/timeline) and back, the selected tab is reset to "all". This happens because the feed page has no reactive URL watcher, while the timeline page has a race condition where it loads data before updating the URL.

2. **Multiple security vulnerabilities** — The codebase has exploitable issues: path traversal in favicon serving, IPv6 address parsing breaking per-IP rate limits, exception messages leaking to HTTP responses, and SSRF vulnerability via feed redirects.

3. **Critical logic bugs** — The feed_more endpoint returns wrong pagination data (ignores offset), the WebSocket message counter double-counts, and socket unregistration double-decrements IP counts.

## What Changes

### Frontend (Tab State Fixes)
- **+page.svelte**: Add URL-watching `$effect` that reloads feeds when URL tab differs from store activeTab; fix `handleTabChange` to load data before updating URL
- **timeline/+page.svelte**: Change `initialized` from plain `let` to `$state`; fix `handleTabChange` to update URL before loading data
- **AppHeader.svelte**: No changes required (already correct)

### Backend (Security Fixes)
- **api_controller.cr**: Add strict allowlist validation for favicon hash/ext parameters; sanitize exception messages in API responses
- **quickheadlines.cr**: Fix IPv6 address parsing for WebSocket connection limits
- **fetcher/feed_fetcher.cr**: Add redirect destination validation to prevent SSRF attacks

### Backend (Logic Bugs)
- **api_controller.cr**: Fix `feed_more` pagination to use correct offset when slicing items
- **socket_manager.cr**: Remove duplicate `messages_sent` increment in broadcast method; fix double-decrement of IP counts in unregister

## Capabilities

### New Capabilities
- `tab-state-persistence`: Ensures the active tab persists across view switches between feed and timeline views. This is a user-facing quality-of-life improvement.

### Modified Capabilities
- `api-security`: The existing API security capability requires hardening against path traversal and SSRF; no spec file currently exists for this, so this fix falls under general security hardening.

## Impact

### Affected Code
- **Frontend**: `frontend/src/routes/+page.svelte`, `frontend/src/routes/timeline/+page.svelte`
- **Backend**: `src/controllers/api_controller.cr`, `src/quickheadlines.cr`, `src/fetcher/feed_fetcher.cr`, `src/websocket/socket_manager.cr`

### Dependencies
- Crystal 1.18.2 (no Time.Instant usage per project requirements)
- Svelte 5 runes ($state, $effect, $derived)

### Breaking Changes
None — all changes are bug fixes and security hardening.

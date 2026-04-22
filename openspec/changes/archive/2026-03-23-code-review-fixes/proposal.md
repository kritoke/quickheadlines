## Why

The QuickHeadlines codebase has several issues identified in code review: (1) missing mobile tab navigation on timeline view causing poor UX, (2) inconsistent state between timeline and feed box views causing data divergence, (3) security vulnerabilities in the image proxy endpoint, and (4) missing rate limiting on expensive API endpoints. These issues impact usability, data consistency, and security.

## What Changes

1. **Add mobile tab selector to timeline view** - Render mobile TabSelector component in timeline page (currently only renders in feed page)
2. **Implement shared app state store** - Create `stores/appState.svelte.ts` for cross-cutting state (tabs, activeTab) used by both views
3. **Add proxy image URL validation** - Implement allowlist-based domain validation in `/proxy_image` endpoint to prevent SSRF
4. **Add rate limiting** - Implement rate limiting on expensive endpoints (clustering, admin actions)
5. **Consolidate duplicate effects logic** - Refactor `effects.svelte.ts` to reuse code between feed and timeline
6. **Add dedicated tabs API endpoint** - Create `/api/tabs` to avoid loading full feed data just for tab names

## Capabilities

### New Capabilities
- `mobile-tab-navigation`: Enables tab selection on mobile devices for timeline view (currently only works on feed view)
- `shared-app-state`: Cross-view state management for tabs and active tab to ensure consistency between feed and timeline views
- `proxy-url-validation`: URL allowlist validation for image proxy to prevent SSRF attacks
- `api-rate-limiting`: Rate limiting on expensive API endpoints to prevent abuse

### Modified Capabilities
- `feed-refresh`: Modify to use shared app state instead of loading feeds for tab list
- `websocket-updates`: Modify to update from single shared state source

## Impact

**Frontend:**
- `frontend/src/routes/timeline/+page.svelte` - Add TabSelector component
- `frontend/src/lib/stores/appState.svelte.ts` - New shared state store
- `frontend/src/lib/stores/effects.svelte.ts` - Refactored to reduce duplication

**Backend:**
- `src/controllers/api_controller.cr` - Add rate limiting, URL validation
- New endpoint: `/api/tabs` - Lightweight tab listing

**Testing:**
- Visual regression tests for mobile tab navigation on timeline
- Integration tests for shared state behavior
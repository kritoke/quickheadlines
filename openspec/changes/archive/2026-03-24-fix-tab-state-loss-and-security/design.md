## Context

QuickHeadlines is a self-hosted RSS/Timeline news aggregator with two main views:
- **Feed view** (`/`): Grid of feed cards organized by tab
- **Timeline view** (`/timeline`): Chronological list of items across feeds

Users select tabs (e.g., "Tech", "News", "all") to filter content. The current implementation has a broken tab state persistence:

**Current Problem:**
1. `feedState` and `timelineState` are module-level singletons (Svelte 5 `$state` at module scope)
2. `+page.svelte` (feed) has no URL-watching `$effect` — it only initializes from the URL on first mount when `feedState` is empty
3. `timeline/+page.svelte` has a race condition: `handleTabChange` loads data BEFORE updating the URL, causing the URL-watcher `$effect` to fire prematurely and revert the tab

**Security Issues:**
- Favicon endpoint has no path traversal protection
- IPv6 address parsing is broken (splits on `:` incorrectly)
- Exception messages leak to HTTP responses
- Feed redirect targets aren't validated for SSRF

**Logic Bugs:**
- `feed_more` pagination ignores offset
- WebSocket `messages_sent` is double-counted
- Socket `unregister` double-decrements IP counts

## Goals / Non-Goals

**Goals:**
- Fix tab state persistence so users don't lose their selected tab when switching between feed and timeline views
- Fix all identified security vulnerabilities (path traversal, SSRF, IPv6 parsing, exception leakage)
- Fix critical logic bugs (pagination, double-counting, double-decrement)

**Non-Goals:**
- Refactor tab architecture to use URL as single source of truth (more invasive)
- Add new features or capabilities
- Change the visual design or user interface
- Add rate limiting beyond fixing the broken IPv6 support

## Decisions

### D1: URL-watching $effect for feed page
**Choice:** Add a reactive `$effect` to `+page.svelte` that watches `$page.url.searchParams.get('tab')` and reloads feeds when the URL tab differs from `feedState.activeTab`.

**Rationale:** This mirrors the existing pattern in `timeline/+page.svelte`, is a minimal change, and preserves the existing tab caching in `feedState.tabCache`.

**Alternative considered:** Making URL the single source of truth (remove `activeTab` from stores). Rejected because it requires larger refactoring and removes the performance benefit of tab caching.

### D2: Fix handleTabChange ordering in timeline page
**Choice:** In `timeline/+page.svelte`'s `handleTabChange`, call `NavigationService.navigateToTimeline(tab)` FIRST, then let the URL-watching `$effect` trigger the data load automatically.

**Rationale:** This eliminates the race condition by ensuring the URL is updated before any reactive dependencies re-evaluate.

### D3: Favicon path validation
**Choice:** Use strict allowlist validation:
- `hash` must match regex `/\A[a-f0-9]{8,64}\z/` (SHA256 hex)
- `ext` must be one of `png|jpg|jpeg|ico|svg|webp`

**Rationale:** This is a defense-in-depth approach. Even if `File.join` doesn't resolve `..`, the allowlist prevents any path manipulation.

### D4: IPv6 address parsing
**Choice:** Use proper `Socket::IPAddress` handling instead of string splitting.

**Rationale:** The current code `ctx.request.remote_address.to_s.split(":").first` fails for IPv6 addresses like `::1` or `[::1]:12345`.

### D5: WebSocket message counter
**Choice:** Remove the increment from `broadcast` method; keep only the increment in `writer_fiber`.

**Rationale:** The message is counted when actually sent (writer_fiber), not when queued (broadcast). Counting at both points is incorrect.

### D6: Socket unregister double-decrement
**Choice:** Have `unregister` NOT call `unregister_connection` — let the `writer_fiber` handle cleanup when it catches `Channel::ClosedError`.

**Rationale:** The channel close triggers `writer_fiber` to exit and call `unregister_connection`. Calling it again from `unregister` causes double-decrement.

## Risks / Trade-offs

**[Risk]** Race condition in feed page URL watcher
→ **Mitigation:** The new `$effect` in `+page.svelte` checks both `feedState.status` and `feedState.feeds.length` before reloading, preventing unnecessary re-loads while maintaining reactivity.

**[Risk]** URL-first approach may cause brief flash of old data
→ **Mitigation:** Minimal — the navigation is client-side and the effect runs synchronously. The data is cached, so switching tabs is nearly instant.

**[Risk]** Feed redirect SSRF fix may block legitimate redirects
→ **Mitigation:** The existing `validate_proxy_url` method is repurposed with the same IP range blocking logic used for image proxy.

**[Risk]** Breaking change to existing favicon URLs
→ **Mitigation:** The validation regex `/\A[a-f0-9]{8,64}\z/` accepts all current SHA256 hashes (64 hex chars) and future SHA256 hashes. Old MD5-based hashes (32 chars) won't work, but those aren't currently used.

## Migration Plan

1. Deploy frontend changes (tab state fix) — no database changes
2. Deploy backend security fixes — no database changes  
3. Deploy backend logic bug fixes — no database changes

All changes are backward-compatible. Rollback is simply reverting to the previous binary.

## Open Questions

None — all technical decisions have been resolved in this design.

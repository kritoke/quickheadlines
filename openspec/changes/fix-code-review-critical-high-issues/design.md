## Context

A code review identified 9 critical and high severity issues across the Crystal backend and Svelte frontend. The application is an RSS feed aggregator with real-time WebSocket updates, serving both web UI and API consumers. The issues span security (XSS, CSS injection, SSRF, IP spoofing, timing attacks), stability (memory leaks), and availability (missing rate limits).

The codebase uses:
- **Backend**: Crystal 1.18.2 with Athena framework, SQLite with BakedFileSystem
- **Frontend**: Svelte 5 with runes, TypeScript, Vite
- **Real-time**: WebSocket with in-memory rate limiting

## Goals / Non-Goals

**Goals:**
- Fix all 4 CRITICAL issues (XSS in 2 components, CSS injection, SSRF in favicon fetch)
- Fix all 5 HIGH issues (IP spoofing, timing leak, memory leak, missing rate limits, double-fetch)
- Ensure no regression in existing functionality
- Maintain Crystal 1.18.2 compatibility (no `Time.instant` usage)

**Non-Goals:**
- Not a full security audit — only the identified issues
- Not adding new features — only fixing bugs
- Not changing architecture — targeted fixes only
- Not modifying the database schema

## Decisions

### 1. Use existing sanitization utilities
The codebase already has `sanitizeUrl()` and `sanitizeCssColor()` in `frontend/src/lib/utils/validation.ts`. These are proven to work (FeedBox.svelte already uses them correctly). The fix is to **apply these existing utilities** consistently in TimelineView, ClusterExpansion, and feedItem.ts rather than creating new ones.

### 2. SSRF protection via host validation before redirect
`FaviconStorage.fetch_and_save()` will validate the **final resolved host** after any redirects using the existing `Utils.private_host?()` function before making the HTTP connection. This is the simplest approach given the existing utility exists.

### 3. X-Forwarded-For: take first IP, not last
When `TRUSTED_PROXY` is set, the code should take the **first** (leftmost) IP from `X-Forwarded-For` as that represents the original client. The current code takes the **last** (rightmost), which is the most recent proxy — which could be attacker-controlled.

### 4. Timing-safe compare without length leak
Replace the early `return false unless a.bytesize == b.bytesize` with a constant-time comparison that compares all bytes regardless of length. The shorter string is padded with null bytes to match the longer one's length before comparison.

### 5. Rate limiting via existing infrastructure
Use the existing `RateLimiter` class (already used for admin endpoints and proxy controller) for `/api/feeds` and `/api/timeline`. This avoids introducing new infrastructure.

### 6. XML parser: remove NOENT only
Remove `XML::ParserOptions::NOENT` to prevent entity substitution attacks. Keep `RECOVER` for malformed XML tolerance. HTML entity unescaping for titles is already handled manually by `HTML.unescape()`.

## Risks / Trade-offs

- **[Risk]** Changing X-Forwarded-For handling from last to first IP might break legitimate setups where proxies append IPs → **Mitigation**: This is the correct behavior per RFC 7239. Proxies should set X-Forwarded-For as a comma-separated list of IPs from left (original) to right (most recent). Taking the first is standard practice.
- **[Risk]** Adding rate limits might break legitimate high-traffic usage → **Mitigation**: Rate limits are set at 60 req/min per IP, which is generous for a feed reader (users don't refresh more than once per minute typically).
- **[Risk]** Removing NOENT might cause some malformed feeds to parse differently → **Mitigation**: `RECOVER` is kept, which handles most malformed XML gracefully. Entity substitution was only a small part of NOENT.
- **[Risk]** Timeline effect cleanup might cause flash of unstyled content on navigation → **Mitigation**: Cleanup is called on unmount via Svelte's `$effect` return function, which runs before the component is removed from DOM.

## Open Questions

- None. All decisions are straightforward security fixes with clear implementations.

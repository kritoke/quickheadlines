## Context

Reddit feeds currently bypass HTTP caching. Every refresh fetches full content from Reddit's API endpoints:
- JSON: `reddit.com/r/{subreddit}/hot.json`
- RSS: `reddit.com/r/{subreddit}.rss`

RSS feeds already use conditional requests via the `Fetcher` library, but Reddit feeds use custom fetching in `src/fetcher_adapter.cr` that ignores etag/last_modified entirely.

## Goals / Non-Goals

**Goals:**
- Add ETag and Last-Modified header support to Reddit feed fetching
- Handle 304 Not Modified responses to avoid re-fetching unchanged content
- Maintain same behavior for users - just faster with less bandwidth

**Non-Goals:**
- Not changing any user-facing functionality
- Not adding new features - just optimizing existing behavior
- Not modifying how Reddit feeds are displayed or parsed

## Decisions

1. **Reuse existing caching pattern**: The RSS fetching code already handles etag/last_modified in `src/fetcher/feed_fetcher.cr`. We'll follow the same pattern for Reddit.

2. **Send both headers**: Reddit API supports both `If-None-Match` (ETag) and `If-Modified-Since`. We'll send both for maximum cache hit rate.

3. **Handle 304 at the adapter level**: When Reddit returns 304, return the previous_data with updated cache headers rather than re-fetching.

4. **Maintain fallback to RSS**: If JSON caching fails, fall back to RSS (existing behavior).

## Risks / Trade-offs

- [Risk] Reddit API may not return ETag/Last-Modified for all requests → **Mitigation**: Only use caching headers when we have them; fall back to full fetch if missing
- [Risk] Cache headers from JSON vs RSS might differ → **Mitigation**: Capture headers from whichever endpoint successfully returns data
- [Risk] Debug logging might be excessive → **Mitigation**: Only log 304 hits (cache success), not every request

## Why

Reddit feeds currently bypass HTTP caching entirely. Every refresh fetches full content from Reddit's API, even when nothing has changed. This wastes bandwidth, increases API load, and slows down feed refreshes unnecessarily. Adding ETag/Last-Modified support will make Reddit feeds behave like RSS feeds - returning 304 Not Modified when content is unchanged.

## What Changes

- Modify `fetch_reddit_feed()` to accept and use `etag` and `last_modified` caching parameters
- Update `fetch_reddit_json()` to send `If-None-Match` and `If-Modified-Since` headers and handle 304 responses
- Update `fetch_reddit_rss()` similarly for RSS fallback
- Update `build_reddit_result()` to capture and return caching headers from Reddit responses
- Handle 304 responses in `pull_feed()` by returning previous_data with updated cache headers
- Add debug logging for 304 responses to verify caching works

## Capabilities

### New Capabilities
- `reddit-feed-caching`: Implement HTTP conditional request support for Reddit feeds using ETag and Last-Modified headers

### Modified Capabilities
- None - this is a backend optimization that doesn't change any user-facing behavior or requirements

## Impact

- **Code**: `src/fetcher_adapter.cr` - add caching header support to Reddit feed fetching
- **Performance**: Reduced network usage and faster refreshes when Reddit content unchanged
- **API**: Reddit API receives fewer requests, reducing rate limiting risk

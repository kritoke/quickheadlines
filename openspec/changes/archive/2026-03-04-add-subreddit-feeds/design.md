## Context

QuickHeadlines currently supports RSS/Atom feeds via `fetcher.cr` and `parser.cr`. Users want to track Reddit subreddit posts alongside RSS feeds. Reddit provides a public JSON API that returns posts as JSON without authentication (read-only access).

Current architecture:
- `Feed` struct in `config.cr` stores feed configuration (title, url, auth)
- `fetch_feed()` in `fetcher.cr` fetches and parses RSS/Atom feeds
- `parse_feed()` in `parser.cr` converts XML to `FeedData`
- `FeedData` contains title, url, site_link, items array, favicon info
- Items have title, link, and pub_date

The system uses caching, retry logic, and health monitoring for feeds.

## Goals / Non-Goals

**Goals:**
- Add Reddit subreddit as a first-class feed source type
- Fetch subreddit posts via Reddit's public JSON API
- Convert Reddit posts to the existing `FeedData` format for seamless display
- Handle Reddit rate limits gracefully (60 req/min for public API)
- Support subreddit title, site_link, and favicon display
- Integrate with existing caching and refresh loop systems

**Non-Goals:**
- Reddit authentication (OAuth, API keys) - public API is sufficient
- Comment fetching - only post titles and links
- Upvote/downvote tracking or interaction
- Multiple sort types (e.g., top, rising) - default to "hot" or "new"
- Subreddit search or discovery - users provide explicit subreddit names

## Decisions

### 1. Subreddit Feed Detection in Config

**Decision**: Add optional `subreddit` field to `Feed` struct. If present, fetch from Reddit API instead of RSS.

**Rationale**:
- Cleaner than special URL patterns (e.g., `reddit:r/technology`)
- Explicit and type-safe (compiler validates)
- Doesn't break existing feed URLs
- Allows both RSS and subreddit to coexist if needed

**Alternatives considered:**
- Special URL prefix (`reddit://r/tech`) - requires URL parsing, less discoverable
- Separate `Subreddit` config type - duplicates logic, adds complexity
- Heuristic detection (check if URL contains `reddit.com`) - fragile, false positives

### 2. Reddit API Endpoint and Format

**Decision**: Use Reddit's public JSON API (`https://www.reddit.com/r/<subreddit>/<sort>.json`) with no authentication.

**Rationale**:
- Public API doesn't require OAuth for read-only access
- Simple HTTP GET request, returns JSON
- 60 requests/minute rate limit is sufficient for typical use (refresh every 10-30 min)
- No API keys or secrets to manage

**Alternatives considered:**
- Official Reddit API with OAuth - overkill for read-only, requires client registration
- Private API (`api.reddit.com`) - undocumented, may break
- Third-party Reddit APIs - adds external dependency

### 3. Sort Order Default

**Decision**: Default to "hot" sort, allow configuration via optional `sort` field.

**Rationale**:
- "Hot" shows trending posts, most relevant for news tracking
- "New" can be configured for real-time monitoring
- Consistent with Reddit's default web view

**Alternatives considered:**
- Hardcode "new" - less relevant for news, chronological overload
- Always "hot" - limits flexibility for use cases

### 4. JSON to FeedData Mapping

**Decision**: Map Reddit JSON structure to existing `FeedData` format:
- `data.children[].data.title` → Item.title
- `data.children[].data.url` → Item.link
- `data.children[].data.created_utc` → Item.pub_date
- `data.title` (subreddit name) → FeedData.title
- `https://www.reddit.com/r/<subreddit>` → FeedData.site_link

**Rationale**:
- Reuses existing UI and clustering without changes
- Familiar format for users
- Minimal code duplication

**Alternatives considered:**
- New `SubredditData` type - requires UI changes, violates DRY

### 5. Module Placement

**Decision**: Create new `reddit_fetcher.cr` module, integrate with existing `fetcher.cr`.

**Rationale**:
- Keeps Reddit logic isolated and testable
- `fetcher.cr` delegates to `fetch_subreddit()` when `subreddit` field present
- Follows pattern of `github_fetcher.cr` (software releases)

**Alternatives considered:**
- Add to existing `fetcher.cr` - grows too large (already 800+ lines)
- Add to `parser.cr` - wrong responsibility (fetching, not parsing)

### 6. Error Handling and Rate Limits

**Decision**: Use existing retry logic in `fetch_feed()`, add Reddit-specific error handling for 429 (rate limit).

**Rationale**:
- Consistent with RSS feed error handling
- Leverages existing retry/backoff infrastructure
- 429 responses can wait and retry

**Alternatives considered:**
- Separate rate limiter - adds complexity, not needed for 60 req/min

### 7. Favicon Handling

**Decision**: Use subreddit-specific icon from Reddit's API or fallback to Google favicon service.

**Rationale**:
- Reddit doesn't provide per-subreddit favicons in the JSON
- Can use `https://www.reddit.com/r/<subreddit>/about.json` → `data.icon_img`
- Fallback to Google favicon service (existing code)

**Alternatives considered:**
- Use generic Reddit icon - less visual distinction
- Skip favicons - inconsistent with RSS feeds

## Risks / Trade-offs

**Risk**: Reddit public API may change or be deprecated.  
→ Mitigation: Use stable endpoints (`/r/<sub>/<sort>.json`), monitor for changes, error handling graceful degradation.

**Risk**: Rate limit (60 req/min) may be hit with many subreddits.  
→ Mitigation: Stagger requests in refresh loop, use 10-minute default refresh (6 subreddits = 36 req/min well under limit).

**Risk**: NSFW or inappropriate content may appear.  
→ Mitigation: Add `over18` flag in config to optionally filter, respect user preferences (not enforced by default for freedom).

**Trade-off**: Public API means no user-specific feeds (subscribed subreddits).  
→ Acceptable for initial implementation, OAuth can be added later if requested.

**Trade-off**: JSON parsing is different from RSS parsing.  
→ Necessary for Reddit, isolated in `reddit_fetcher.cr` to avoid polluting RSS code.

## Migration Plan

1. Add `subreddit` and optional `sort` fields to `Feed` struct in `config.cr`
2. Create `reddit_fetcher.cr` module with `fetch_subreddit()` function
3. Modify `fetch_feed()` in `fetcher.cr` to check for `subreddit` field and delegate
4. Update `refresh_all()` to handle subreddits (already generic)
5. Test with example subreddit in `feeds.yml`
6. Documentation update

**Rollback**: Remove `reddit_fetcher.cr`, revert `fetch_feed()` and `config.cr` changes, delete subreddit entries from config.

## Open Questions

- Should we support Reddit's "top" sort with time periods (day, week, month, year, all)?  
  → Defer to follow-up if users request. Default "hot" covers most use cases.

- Should we fetch and display post score (upvotes) or comment count?  
  → Defer to follow-up. Current `Item` struct only has title, link, pub_date.

- Should we filter out stickied posts (announcements that stay at top)?  
  → No, they're relevant content. Users can ignore if unwanted.

## ADDED Requirements

### Requirement: Subreddit feed configuration
The system SHALL support configuring Reddit subreddit feeds via an optional `subreddit` field in the Feed configuration. When present, the system SHALL fetch posts from Reddit instead of treating the feed as an RSS source.

#### Scenario: Valid subreddit configuration
- **WHEN** user adds a feed with `subreddit: technology` in feeds.yml
- **THEN** system recognizes it as a subreddit feed and fetches from Reddit API

#### Scenario: Invalid subreddit name
- **WHEN** user provides an invalid subreddit name (empty or contains invalid characters)
- **THEN** system logs an error and does not attempt to fetch from Reddit

#### Scenario: Missing subreddit field
- **WHEN** feed configuration has no `subreddit` field
- **THEN** system treats it as a regular RSS/Atom feed

### Requirement: Subreddit post fetching
The system SHALL fetch subreddit posts from Reddit's public JSON API endpoint `https://www.reddit.com/r/<subreddit>/<sort>.json`. The system SHALL use "hot" as the default sort order.

#### Scenario: Successful subreddit fetch
- **WHEN** system fetches posts from `/r/technology/hot.json`
- **THEN** system receives a JSON response containing post data

#### Scenario: Custom sort order
- **WHEN** feed configuration includes `sort: new`
- **THEN** system fetches from `/r/<subreddit>/new.json`

#### Scenario: Rate limit handling
- **WHEN** Reddit API returns HTTP 429 (rate limit exceeded)
- **THEN** system waits using existing retry logic and retries the request

### Requirement: Reddit JSON to FeedData conversion
The system SHALL convert Reddit post JSON to the existing FeedData format, mapping Reddit fields to QuickHeadlines fields.

#### Scenario: Convert post title
- **WHEN** Reddit post has `data.title`
- **THEN** system maps to `Item.title`

#### Scenario: Convert post URL
- **WHEN** Reddit post has `data.url`
- **THEN** system maps to `Item.link`

#### Scenario: Convert post timestamp
- **WHEN** Reddit post has `data.created_utc` (Unix timestamp)
- **THEN** system converts to Time and maps to `Item.pub_date`

#### Scenario: Convert subreddit metadata
- **WHEN** system fetches subreddit posts
- **THEN** FeedData.title is set to subreddit name (e.g., "r/technology")
- **THEN** FeedData.site_link is set to `https://www.reddit.com/r/<subreddit>`

### Requirement: Subreddit favicon handling
The system SHALL attempt to fetch subreddit-specific favicon from Reddit's about API endpoint and fall back to the Google favicon service.

#### Scenario: Successful favicon fetch
- **WHEN** system requests `https://www.reddit.com/r/<subreddit>/about.json`
- **THEN** system extracts `data.icon_img` and uses it as favicon

#### Scenario: Fallback to Google favicon service
- **WHEN** Reddit about API fails or returns no icon
- **THEN** system falls back to Google favicon service for the subreddit URL

### Requirement: Error handling and logging
The system SHALL handle Reddit API errors gracefully and log appropriate messages for debugging.

#### Scenario: Subreddit not found
- **WHEN** Reddit API returns HTTP 404 for subreddit
- **THEN** system logs error and returns empty FeedData with error message

#### Scenario: Reddit API timeout
- **WHEN** request to Reddit API times out
- **THEN** system logs timeout and retries using existing retry logic

#### Scenario: Invalid JSON response
- **WHEN** Reddit API returns malformed JSON
- **THEN** system logs parsing error and returns empty FeedData

### Requirement: Item limit enforcement
The system SHALL respect the item limit configuration when fetching subreddit posts, fetching no more than the specified limit.

#### Scenario: Default item limit
- **WHEN** feed has no `item_limit` field
- **THEN** system fetches up to global `item_limit` (default 20) posts

#### Scenario: Custom item limit
- **WHEN** feed configuration includes `item_limit: 50`
- **THEN** system fetches up to 50 posts from the subreddit

### Requirement: Cache integration
The system SHALL integrate subreddit feeds with the existing FeedCache system, storing fetched data for future refresh cycles.

#### Scenario: Cache subreddit feed data
- **WHEN** system successfully fetches subreddit posts
- **THEN** system stores FeedData in FeedCache with appropriate expiration

#### Scenario: Use cached data
- **WHEN** cached subreddit data is fresh and within limit
- **THEN** system returns cached data instead of fetching from Reddit

### Requirement: Integration with refresh loop
The system SHALL integrate subreddit feeds into the existing refresh_all() loop, fetching them concurrently with other feeds.

#### Scenario: Refresh all feeds including subreddits
- **WHEN** system runs refresh_all() with mixed RSS and subreddit feeds
- **THEN** system fetches all feeds concurrently respecting semaphore limits

#### Scenario: Staggered refresh
- **WHEN** system has multiple subreddit feeds configured
- **THEN** system respects semaphore limits to avoid hitting Reddit rate limits

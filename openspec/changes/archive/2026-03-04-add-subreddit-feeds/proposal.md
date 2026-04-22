## Why

Users want to track new posts from Reddit subreddits alongside their RSS feeds, providing a unified view of content from multiple sources.

## What Changes

- Add Reddit subreddit as a new feed source type (using Reddit's public JSON API)
- Extend Feed configuration to support subreddit sources (e.g., `subreddit: technology`)
- Create a Reddit fetcher that converts subreddit posts to FeedData format
- Display subreddit posts in the same timeline/feed view as RSS items
- Support for subreddit title, site_link, and favicon display

## Capabilities

### New Capabilities
- `subreddit-feeds`: Track and display new posts from Reddit subreddits using Reddit's public JSON API

### Modified Capabilities
- None (existing feed capabilities remain unchanged)

## Impact

- New `reddit_fetcher.cr` module to fetch subreddit posts
- Extension of `Feed` configuration to support subreddit type
- Integration with existing feed refresh loop and caching system
- No breaking changes to existing RSS feed functionality

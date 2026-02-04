## 1. Configuration Changes

- [ ] 1.1 Add `subreddit` field (String?) to Feed struct in src/config.cr
- [ ] 1.2 Add `sort` field (String?) to Feed struct in src/config.cr with default "hot"
- [ ] 1.3 Add `over18` field (Bool?) to Feed struct in src/config.rs for optional NSFW filtering

## 2. Reddit Fetcher Module

- [ ] 2.1 Create src/reddit_fetcher.cr module file
- [ ] 2.2 Define RedditPost struct to hold parsed post data (title, url, created_utc, permalink)
- [ ] 2.3 Define RedditResponse struct to hold API response (data: RedditData)
- [ ] 2.4 Define RedditData struct to hold response data (children: Array<RedditChild>)
- [ ] 2.5 Define RedditChild struct (kind, data: RedditPost)
- [ ] 2.6 Implement `fetch_subreddit(feed: Feed, limit: Int32) -> FeedData` function
- [ ] 2.7 Add Reddit API endpoint URL construction in fetch_subreddit
- [ ] 2.8 Add HTTP GET request with proper headers (User-Agent) in fetch_subreddit
- [ ] 2.9 Add JSON parsing response body in fetch_subreddit
- [ ] 2.10 Add error handling for HTTP 429 (rate limit) in fetch_subreddit
- [ ] 2.11 Add error handling for HTTP 404 (not found) in fetch_subreddit
- [ ] 2.12 Add error handling for HTTP timeouts in fetch_subreddit
- [ ] 2.13 Add error handling for JSON parse errors in fetch_subreddit
- [ ] 2.14 Implement Unix timestamp (created_utc) to Time conversion
- [ ] 2.15 Map Reddit posts to Item objects (title, link, pub_date)
- [ ] 2.16 Enforce item_limit when processing posts
- [ ] 2.17 Set FeedData.title to "r/<subreddit>" format
- [ ] 2.18 Set FeedData.site_link to "https://www.reddit.com/r/<subreddit>"

## 3. Favicon Handling

- [ ] 3.1 Implement `fetch_subreddit_favicon(subreddit: String) -> String?` function in reddit_fetcher.cr
- [ ] 3.2 Add HTTP GET request to Reddit about API endpoint in fetch_subreddit_favicon
- [ ] 3.3 Parse icon_img field from about.json response
- [ ] 3.4 Add fallback to FaviconHelper.google_favicon_url if about API fails
- [ ] 3.5 Integrate favicon fetching into fetch_subreddit function

## 4. Integration with Fetcher

- [ ] 4.1 Modify `fetch_feed()` function in src/fetcher.cr to check for subreddit field
- [ ] 4.2 Add conditional delegation to `fetch_subreddit()` when subreddit field is present
- [ ] 4.3 Keep existing RSS/Atom fetching logic when subreddit field is absent
- [ ] 4.4 Ensure existing retry/backoff logic applies to subreddit fetches
- [ ] 4.5 Ensure existing health monitoring applies to subreddit fetches

## 5. Refresh Loop Integration

- [ ] 5.1 Verify refresh_all() in fetcher.cr works with mixed feed types (no changes needed)
- [ ] 5.2 Test that subreddit feeds are included in concurrent fetch operations
- [ ] 5.3 Verify semaphore limits prevent Reddit rate limit violations

## 6. Validation

- [ ] 6.1 Add validation for subreddit field in validate_feed() function in config.cr
- [ ] 6.2 Add warning for empty subreddit name
- [ ] 6.3 Add warning for invalid subreddit characters (if any validation needed)

## 7. Testing

- [ ] 7.1 Add example subreddit feed to feeds.yml for manual testing
- [ ] 7.2 Test fetching valid subreddit (e.g., technology) with default sort
- [ ] 7.3 Test fetching subreddit with custom sort (new)
- [ ] 7.4 Test invalid subreddit (non-existent) error handling
- [ ] 7.5 Test rate limit behavior (simulate with multiple subreddits)
- [ ] 7.6 Test favicon fetching with existing subreddit
- [ ] 7.7 Test favicon fallback behavior
- [ ] 7.8 Test cache integration (verify subreddit data is cached)
- [ ] 7.9 Test item limit enforcement
- [ ] 7.10 Test mixed feed types (RSS + subreddit) in feeds.yml

## 8. Documentation

- [ ] 8.1 Update feeds.yml comments to include subreddit feed example
- [ ] 8.2 Document subreddit feed configuration options (subreddit, sort, item_limit)
- [ ] 8.3 Document Reddit API rate limit (60 req/min)
- [ ] 8.4 Add troubleshooting notes for common Reddit API errors

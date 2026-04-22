## 1. Implementation

- [x] 1.1 Modify fetch_reddit_feed() to accept etag and last_modified parameters
- [x] 1.2 Update fetch_reddit_json() to send If-None-Match and If-Modified-Since headers
- [x] 1.3 Update fetch_reddit_json() to handle 304 responses - return empty entries with cache marker
- [x] 1.4 Extract ETag and Last-Modified from Reddit JSON response headers
- [x] 1.5 Update fetch_reddit_rss() to send caching headers and handle 304 similarly
- [x] 1.6 Update build_reddit_result() to capture and return caching headers
- [x] 1.7 Handle 304 in pull_feed() - return previous_data with updated cache headers

## 2. Testing & Verification

- [x] 2.1 Run crystal build to verify no syntax errors
- [x] 2.2 Run crystal spec to verify all tests pass
- [x] 2.3 Verify debug logging shows 304 handling (test manually or add debug output)

## 3. Cleanup

- [x] 3.1 Run ameba --fix to ensure code style
- [x] 3.2 Archive OpenSpec change

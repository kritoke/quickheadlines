## 1. Helper Method Extraction

- [x] 1.1 Create `build_reddit_headers(etag, last_modified)` helper method
- [x] 1.2 Create `handle_reddit_304(response, etag, last_modified)` helper method
- [x] 1.3 Create `reddit_http_client(url)` helper with 10s connect/30s read timeouts

## 2. Update Reddit Fetching Methods

- [x] 2.1 Update `fetch_reddit_json()` to use helper methods
- [x] 2.2 Update `fetch_reddit_json()` to capture updated headers from 304 response
- [x] 2.3 Update `fetch_reddit_json()` to use HTTP client with timeouts
- [x] 2.4 Update `fetch_reddit_rss()` to use helper methods
- [x] 2.5 Update `fetch_reddit_rss()` to capture updated headers from 304 response
- [x] 2.6 Update `fetch_reddit_rss()` to use HTTP client with timeouts

## 3. Code Quality Improvements

- [x] 3.1 Remove redundant `cached` variable in `pull_feed()` (use previous_data directly)
- [x] 3.2 Improve nil safety for title extraction in `fetch_reddit_json()`
- [x] 3.3 Add unit tests for helper methods (extracted parse_reddit_post and extract_reddit_timestamp)

## 4. Testing & Verification

- [x] 4.1 Run crystal build to verify no syntax errors
- [x] 4.2 Run crystal spec to verify all tests pass
- [x] 4.3 Run ameba to verify cyclomatic complexity is below threshold
- [x] 4.4 Manual test with Reddit feeds to verify caching still works

## 5. Cleanup

- [x] 5.1 Archive OpenSpec change

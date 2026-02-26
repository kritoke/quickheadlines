# Tasks: fetcher-enhancements

- [ ] **Task 1: Add Retry Configuration**
  - [ ] Create `retry_config.cr` with configurable retry options
  - [ ] Add retry logic to RSSDriver
  - [ ] Add retry logic to RedditDriver
  - [ ] Add retry logic to SoftwareDriver

- [ ] **Task 2: Add Item Limit Parameter**
  - [ ] Update Driver base class to accept limit
  - [ ] Implement item limiting in RSSDriver
  - [ ] Apply limit during XML parsing (not after)

- [ ] **Task 3: Add GitHub Rate Limiting**
  - [ ] Parse X-RateLimit headers
  - [ ] Handle 429 responses with proper backoff
  - [ ] Wait for rate limit reset if possible

- [ ] **Task 4: Add Connection Pooling**
  - [ ] Create HTTPClientPool module
  - [ ] Update all drivers to use pooled clients

- [ ] **Task 5: Add Logging Support**
  - [ ] Add logger class property to Fetcher module
  - [ ] Add logging calls for key events
  - [ ] Update adapter to configure logger

- [ ] **Task 6: Tests**
  - [ ] Add tests for retry logic
  - [ ] Add tests for rate limit handling
  - [ ] Add tests for item limits

- [ ] **Task 7: Integration**
  - [ ] Update FetcherAdapter to use new features
  - [ ] Verify build passes
  - [ ] Run all specs

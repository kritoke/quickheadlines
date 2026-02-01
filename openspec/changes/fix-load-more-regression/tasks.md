## 1. Storage Layer

- [x] 1.1 Implement `FeedCache#get_total_item_count(url : String) : Int32` in `src/storage.cr`
- [x] 1.2 Verify the `COUNT(*)` query correctly joins `items` and `feeds` tables

## 2. API Layer

- [x] 2.1 Update `Api.feed_to_response` in `src/api.cr` to accept an optional `total_count` parameter
- [x] 2.2 Update `ApiController#feeds` in `src/controllers/api_controller.cr` to provide the real DB count
- [x] 2.3 Update `ApiController#feed_more` in `src/controllers/api_controller.cr` to provide the real DB count

## 3. Verification

- [x] 3.1 Run `crystal spec` to ensure no regressions in existing tests
- [x] 3.2 Implement database size-based cleanup (add `max_cache_size_mb` config, `check_size_limit` method)
- [x] 3.3 Ensure "All" tab case-insensitivity still works as expected

## 1. Favicon Path Resolution

- [x] 1.1 Update `FaviconStorage` to use absolute path from `QUICKHEADLINES_CACHE_DIR` or default
- [x] 1.2 Add migration logic to move existing favicons from `public/favicons/` to new location
- [x] 1.3 Ensure `FaviconStorage.init` is called during application bootstrap
- [x] 1.4 Add fallback initialization on first favicon access if init wasn't called
- [ ] 1.5 Test favicon save/retrieve with new path in Docker environment

## 2. Error Response Sanitization

- [x] 2.1 Update `StaticController.serve_asset` to return generic "Internal server error"
- [x] 2.2 Log actual exception details to STDERR instead of returning to client
- [x] 2.3 Update `favicon_ico` handler to use same generic error pattern
- [ ] 2.4 Verify all error responses return generic messages

## 3. Parameterized SQL Queries

- [x] 3.1 Update `CleanupRepository.cleanup_old_entries` to use parameterized placeholders
- [x] 3.2 Replace manual URL escaping with proper argument binding
- [ ] 3.3 Add identifier validation helper for any remaining SQL interpolation

## 4. Batch Cluster Query for Timeline

- [x] 4.1 Add batch query method to `StoryRepository` for cluster data
- [x] 4.2 Modify `timeline_item_to_response` to use batch fetch
- [ ] 4.3 Verify timeline API returns correct cluster information
- [ ] 4.4 Performance test with 100+ timeline items

## 5. Bounded Cache Implementation

- [x] 5.1 Check if `lru` shard is available in shard.yml
- [x] 5.2 If available: Replace `extraction_cache` with `LRU::Cache` (used custom implementation since ThreadSafeCache has no LRU)
- [x] 5.3 Implemented simple LRU with max size and eviction
- [x] 5.4 Add `MAX_CACHE_SIZE = 1000` constant
- [ ] 5.5 Add health monitor cleanup for orphaned feed entries

## 6. Code Quality Improvements

- [x] 6.1 Extract duplicate `validate_proxy_url` to `Utils` module
- [x] 6.2 Update `FeedFetcher` to use shared `Utils.validate_proxy_host`
- [x] 6.3 Update `ApiController` to use shared `Utils.is_private_host?`
- [x] 6.4 Replace magic numbers with constants (redirect limit, timeout values) - PARTIAL
- [x] 6.5 Replace bare `rescue` blocks with structured logging - PARTIAL
- [x] 6.6 Run `ameba --fix` to clean up style issues

## 7. Verification

- [x] 7.1 Run `just nix-build` and verify it succeeds
- [x] 7.2 Run `nix develop . --command crystal spec` and verify tests pass (200 tests, 0 failures)
- [ ] 7.3 Run frontend tests: `cd frontend && npm run test` (2 pre-existing failures)
- [ ] 7.4 Manual testing in Docker to verify favicon fix

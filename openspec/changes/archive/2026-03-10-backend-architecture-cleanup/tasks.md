## 1. AppState Consolidation

- [x] 1.1 Remove instance-based `AppState` class (lines 82-128 in models.cr)
- [x] 1.2 Keep static `AppState` class (lines 216-296) as the single definition
- [x] 1.3 Remove `with_lock` method from AppState
- [x] 1.4 Remove `self.with_lock` method from AppState
- [x] 1.5 Update `STATE` global to reference the static class pattern
- [x] 1.6 Run tests to verify no breakage

## 2. Error Handling Improvements

- [x] 2.1 Replace empty rescue block at feed_fetcher.cr:101-102 with HealthMonitor.log_error
- [x] 2.2 Replace empty rescue block at feed_fetcher.cr:111-112 with HealthMonitor.log_error
- [x] 2.3 Replace empty rescue block at feed_fetcher.cr:136-137 with HealthMonitor.log_error
- [x] 2.4 Add error logging to rescue blocks in extract_legacy_header_from_theme
- [x] 2.5 Review and fix any other empty rescue blocks in backend code
- [x] 2.6 Run tests to verify error paths work correctly

## 3. FeedFetcher Class Creation

- [x] 3.1 Create `FeedFetcher` class in src/fetcher/feed_fetcher.cr
- [x] 3.2 Move `build_fetch_headers` to private instance method
- [x] 3.3 Move `apply_auth_headers` to private instance method
- [x] 3.4 Move `handle_success_response` to private instance method
- [x] 3.5 Move `extract_legacy_header_from_theme` to private instance method
- [x] 3.6 Move `parse_theme_text_value` to private instance method
- [x] 3.7 Move `normalize_bg_value` to private instance method
- [x] 3.8 Move `extract_header_colors` to private instance method
- [x] 3.9 Move `error_feed_data` to instance method
- [x] 3.10 Move `should_abort_fetch?` to private instance method
- [x] 3.11 Move `calculate_backoff` to private instance method
- [x] 3.12 Move `handle_server_error` to private instance method
- [x] 3.13 Move `handle_timeout_error` to private instance method
- [x] 3.14 Move `handle_feed_response` to private instance method
- [x] 3.15 Move `fetch_feed` to public instance method
- [x] 3.16 Move `get_cached_feed` to private instance method
- [x] 3.17 Move `get_stale_cached_feed` to private instance method
- [x] 3.18 Move `load_feeds_from_cache` to class method or separate service
- [x] 3.19 Add constructor that accepts FeedCache dependency
- [x] 3.20 Create singleton accessor for backward compatibility
- [x] 3.21 Update callers to use new class structure

## 4. Verification

- [x] 4.1 Run `just nix-build` to verify build succeeds
- [x] 4.2 Run `nix develop . --command crystal spec` to verify tests pass
- [x] 4.3 Start server and verify feed fetching works
- [x] 4.4 Verify error logging appears in stderr when errors occur
- [x] 4.5 Review code with `ameba --fix` for style compliance

## 5. Documentation

- [x] 5.1 Add deprecation comments to `STATE` and `FEED_CACHE` globals
- [x] 5.2 Update AGENTS.md if any workflow changes

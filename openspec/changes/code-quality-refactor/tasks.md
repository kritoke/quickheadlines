## 1. Dead Code & Duplicate Removal

- [x] 1.1 Remove duplicate `find_light_text_for_bg_public` in color_extractor.cr, rename `find_dark_text_for_bg_public` to `suggest_foreground_for_bg`
- [x] 1.2 Remove duplicated DB helpers in database_service.cr that duplicate CacheUtils methods

## 2. Structs for Tuple Returns

- [x] 2.1 Add `FetchAbortDecision` record and update `should_abort_fetch?` in feed_fetcher.cr
- [x] 2.2 Add `FetchErrorResult` record and update `handle_fetch_exception` in feed_fetcher.cr

## 3. Row-Reading Helpers in FeedRepository

- [x] 3.1 Extract `read_feed_entity(row)` private method to replace duplicated row mapping
- [x] 3.2 Extract `read_item(row)` private method to replace duplicated item row mapping
- [x] 3.3 Refactor `find_all`, `find_by_url`, `find_with_items`, `find_with_items_slice` to use helpers

## 4. Magic Numbers → Constants

- [x] 4.1 Add `CACHE_FRESHNESS_MINUTES = 5`, `MAX_BACKOFF_SECONDS = 60`, `FETCH_BUFFER_ITEMS = 50`, `BROADCAST_TIMEOUT_MS = 100` to constants.cr
- [x] 4.2 Replace magic number `5` in feed_fetcher.cr:376 with `Constants::CACHE_FRESHNESS_MINUTES`
- [x] 4.3 Replace magic number `60` in feed_fetcher.cr:361 with `Constants::MAX_BACKOFF_SECONDS`
- [x] 4.4 Replace magic number `50` in feeds_controller.cr:100 with `Constants::FETCH_BUFFER_ITEMS`
- [x] 4.5 Replace magic number `100` in socket_manager.cr:154 with `Constants::BROADCAST_TIMEOUT_MS`
- [x] 4.6 Add `FaviconStorage::HASH_PREFIX_LENGTH = 16` and replace hardcoded `16` in favicon_storage.cr

## 5. Rate-Limit Helper in AdminController

- [x] 5.1 Extract `with_rate_limit(key, ip, max_requests, window_seconds, &)` helper method
- [x] 5.2 Refactor `cluster` and `admin` endpoints to use the helper

## 6. IP Count Helper in SocketManager

- [x] 6.1 Extract `decrement_ip_count(ip)` private method
- [x] 6.2 Refactor `unregister_connection` and `cleanup_dead_connections` to use helper

## 7. Text Value Normalization in ColorExtractor

- [x] 7.1 Extract `normalize_text_value(val)` to handle Hash/String/JSON::Any inputs
- [x] 7.2 Refactor `get_cached_theme_aware` and `cache_result_theme_aware` to use it

## 8. Flatten ColorExtractor Conditionals

- [x] 8.1 Refactor `auto_correct_theme_json` with early returns and extracted helpers

## 9. Rename Unclear Variables

- [x] 9.1 Rename `fd` to `feed_data` in feed_fetcher.cr
- [x] 9.2 Rename `SEM` to `CONCURRENCY_SEMAPHORE` in utils.cr
- [x] 9.3 Rename `sw_config` / `sw_box` to `software_config` / `software_feed` in refresh_loop.cr

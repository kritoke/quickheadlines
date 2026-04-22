## Why

The codebase has accumulated several code quality issues that reduce maintainability and increase bug risk: duplicate code, magic numbers, confusing naming, over-complicated conditionals, and inconsistent patterns. Addressing these systematically improves long-term maintainability and reduces cognitive load for future changes.

## What Changes

- **Remove dead/duplicate code**: Eliminate identical `find_dark_text_for_bg_public` and `find_light_text_for_bg_public` methods (color_extractor.cr). Consolidate duplicated DB helper methods in `DatabaseService` that mirror `CacheUtils`.
- **Extract row-reading helpers**: Shared logic in `FeedRepository` for mapping DB rows to entities is repeated 4+ times. Extract `read_feed_entity` and `read_item` private methods.
- **Replace tuples with structs**: Replace bare `Tuple(Bool, String?)` returns with named `FetchAbortDecision` and `FetchErrorResult` records for clarity.
- **Eliminate magic numbers**: Extract hardcoded literals (cache freshness threshold, backoff limits, hash truncation length, broadcast timeouts) into named constants.
- **Extract shared helpers**: Pull out duplicated rate-limit checking in `AdminController`, IP count decrement logic in `SocketManager`, and text value normalization in `ColorExtractor`.
- **Flatten nested conditionals**: Deeply nested methods in `FeedFetcher` and `ColorExtractor` refactored with early returns and smaller extracted methods.
- **Rename unclear variables**: `fd` → `feed_data`, `SEM` → `CONCURRENCY_SEMAPHORE`, `sw_config` → `software_config`.

## Capabilities

### New Capabilities
None - this is a pure refactoring change with no new features or changed requirements.

### Modified Capabilities
None - all changes are implementation quality improvements that preserve existing behavior.

## Impact

- **Affected files**: `color_extractor.cr`, `feed_fetcher.cr`, `feed_repository.cr`, `socket_manager.cr`, `admin_controller.cr`, `database_service.cr`, `cache_utils.cr`, `constants.cr`
- **No API changes**: All public interfaces remain identical
- **No behavior changes**: Refactorings are purely internal
- **Dependencies unchanged**: No new gems, shards, or libraries

## Why

The Crystal backend has accumulated ~490 lines of dead code (unused legacy modules), 38 methods with names exceeding 3 words, 8 source files over 300 lines, and repeated DRY violations across repositories and storage modules. This refactoring pass improves maintainability, reduces cognitive load, and enforces consistent Crystal 1.18.2 idioms without changing any external behavior.

## What Changes

- **Delete dead code**: Remove `ClusteringRepository` module (`clustering_repo.cr`, 349 lines) — never imported or used. Remove `CleanupRepository` module (`cleanup.cr`, 142 lines) — only referenced in one spec. Remove legacy `FeedCache` class stub in `models.cr`.
- **Rename long method names**: Shorten 38 methods with 4+ word names to 2-3 words (e.g., `get_feed_theme_colors` → `theme_colors`, `auto_upgrade_to_auto_corrected` → `upgrade_theme_json`).
- **Extract shared helpers**: Create `RepositoryBase` abstract class for the duplicated DB initialization pattern (4 repositories). Extract `CacheUtils.parse_db_time` for the repeated time parsing pattern (15+ occurrences). Add `Config#all_feed_urls` for the duplicated config URL collection (4 locations). Extract `CacheUtils.placeholders` for repeated `?` placeholder building (6 locations).
- **Split large files/methods**: Break `FaviconSyncService#sync_favicon_paths` (148 lines) into focused methods. Split `FeedFetcher#fetch` (97 lines) into smaller responsibilities. Extract `TimelineQueryBuilder` and `StoryRowMapper` from `StoryRepository`.
- **Idiomatic cleanup**: Replace `begin/rescue` blocks with `try` where appropriate. Use `.blank?`/`.presence` over manual nil+empty checks.

## Capabilities

### New Capabilities
- `repository-base`: Shared abstract base class for database repositories, providing uniform DB initialization and common query helpers.
- `cache-utils-helpers`: Shared utility methods for time parsing, SQL placeholder generation, and config URL collection.

### Modified Capabilities
_(No spec-level behavior changes — all changes are internal implementation refactoring with no API or capability contract changes.)_

## Impact

- **Code removal**: ~490 lines of dead code deleted
- **Files affected**: ~20 Crystal source files, 1 spec file (cleanup_spec.cr)
- **API**: No external API changes — all refactoring is internal
- **Dependencies**: No new dependencies
- **Crystal version**: Enforces 1.18.2 compatibility (no `Time.instant`, `Time.monotonic` usage noted but compatible)
- **Risk**: Low — pure refactoring with no behavioral changes; verified by existing test suite

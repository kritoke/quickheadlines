## Context

Code review identified 6 distinct areas of duplicated logic in the Crystal backend. Each duplication ranges from 2-4 copies of essentially the same code. The codebase already has a `CacheUtils` module and shared base classes that suggest consolidation patterns, but several operations were added ad-hoc without factoring out shared helpers.

## Goals / Non-Goals

**Goals:**
- Each piece of logic exists in exactly one place
- Callers use the shared method instead of inline copies
- No behavioral changes — only code movement and deduplication

**Non-Goals:**
- Refactoring the SQL query structure itself (only extracting shared builders)
- Changing the URL normalization algorithm
- Changing the theme text normalization algorithm
- Modifying caching or clustering behavior

## Decisions

### D1: Theme normalization lives in ColorExtractor

`ColorExtractor` already has two normalization methods (`normalize_text_value`, `normalize_text_value_for_storage`). Consolidate all variants into `ColorExtractor` as the canonical location, and have `ThemeHelper` and `FaviconSyncService` call it instead of reimplementing.

### D2: URL normalization canonical location is CacheUtils

`CacheUtils.normalize_feed_url` already wraps `UrlNormalizer.normalize` and is used by `HeaderColorStore`. Make this the single canonical wrapper. Remove `ApiBaseController.normalize_url` and `Utils.UrlNormalizer` direct usage where the wrapper suffices.

### D3: Admin clear_cache delegates entirely to FeedCache

`AdminController#handle_clear_cache` manually runs DELETE SQL then calls `FeedCache.clear_all` which runs the same DELETEs again. Remove the manual SQL and just call `FeedCache.clear_all`. If additional admin-specific cleanup is needed, add methods to the appropriate store/repository.

## Risks / Trade-offs

- **[Caller update遗漏]** → Compiler will catch any missed references since method signatures change
- **[Shared method has subtle differences]** → Each duplicate must be carefully compared. The current duplicates appear identical but edge cases (nil handling, type coercion) need verification

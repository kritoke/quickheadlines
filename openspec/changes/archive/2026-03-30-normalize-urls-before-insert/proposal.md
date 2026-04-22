## Why

Feed items with URLs that differ only in query parameters (e.g., `example.com/article?utm_source=twitter` vs `example.com/article`) are being stored as duplicate entries. This wastes database space, pollutes the timeline with near-identical items, and reduces the effectiveness of deduplication.

## What Changes

- **Modify** `UrlNormalizer.normalize` in `src/utils.cr` to strip query parameters from URLs before comparison/insertion
- **Update** `UrlNormalizer` to handle the `?` character and everything after it when normalizing URLs
- **No schema changes** - existing unique index on `(feed_id, link)` will now work correctly since normalized links won't have query params

## Capabilities

### New Capabilities
- `url-normalization`: Normalize URLs by stripping query parameters and fragments to prevent duplicate items from UTM-tagged and fragment-identifier URLs

### Modified Capabilities
None - existing functionality preserved, only bug fixed.

## Impact

- **Modified Files**: `src/utils.cr` (UrlNormalizer module)
- **Database**: No schema changes needed - existing unique index will work correctly with normalized URLs
- **Breaking Changes**: None - URLs are already being normalized, just not stripping query params
- **Performance**: Minimal - removing query params is a simple string operation

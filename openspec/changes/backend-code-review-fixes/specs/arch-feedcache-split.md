# arch-feedcache-split

**Owner:** Backend Team  
**Status:** proposed

## Overview

Split the `FeedCache` god object into focused, single-responsibility classes composed together. Currently `FeedCache` includes three mixins (`ClusteringRepository`, `HeaderColorsRepository`, `CleanupRepository`) and has a singleton instance used throughout the codebase.

## Requirements

### REQ-001: Standalone ClusteringStore
Extract `ClusteringRepository` mixin into `QuickHeadlines::Storage::ClusteringStore` class:

```crystal
class QuickHeadlines::Storage::ClusteringStore
  def initialize(@db : DB::Database, @mutex : Mutex); end
  # All methods currently in ClusteringRepository mixin
end
```

### REQ-002: Standalone HeaderColorStore
Extract `HeaderColorsRepository` mixin into `QuickHeadlines::Storage::HeaderColorStore` class.

### REQ-003: Standalone CleanupStore
Extract `CleanupRepository` mixin into `QuickHeadlines::Storage::CleanupStore` class.

### REQ-004: FeedCache Facade
`QuickHeadlines::Storage::FeedCache` composes the three stores and delegates:

```crystal
class QuickHeadlines::Storage::FeedCache
  include ClusteringRepository
  include HeaderColorsRepository
  include CleanupRepository
  
  def initialize(..., @clustering : ClusteringStore, @colors : HeaderColorStore, @cleanup : CleanupStore)
    # ...
  end
end
```

### REQ-005: Backward Compatibility
All existing public method signatures on `FeedCache` remain identical. Existing callers (controllers, services) require no changes.

### REQ-006: `FeedCache.instance`
The `FeedCache.instance` singleton is retained for `api.cr` and BakedFileSystem compatibility. It creates a default instance with the three stores.

## Acceptance Criteria

- [ ] `ClusteringStore`, `HeaderColorStore`, `CleanupStore` are standalone classes
- [ ] `FeedCache` composes the three stores
- [ ] All existing `FeedCache` public method signatures are unchanged
- [ ] All existing callers compile without modification
- [ ] `FeedCache.instance` returns a properly initialized instance

## Affected Files

- `src/storage/clustering_store.cr` — NEW (extracted from `clustering_repo.cr`)
- `src/storage/header_color_store.cr` — NEW (extracted from `header_colors.cr`)
- `src/storage/cleanup_store.cr` — NEW (extracted from `cleanup.cr`)
- `src/storage/feed_cache.cr` — Refactored to compose stores
- `src/storage/clustering_repo.cr` — Convert mixin to module that `ClusteringStore` includes
- `src/storage/header_colors.cr` — Convert mixin to module that `HeaderColorStore` includes
- `src/storage/cleanup.cr` — Convert mixin to module that `CleanupStore` includes

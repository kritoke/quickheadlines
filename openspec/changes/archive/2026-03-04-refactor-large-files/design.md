## Context

The codebase has three monolithic source files that have grown organically over time:
- `storage.cr` (1647 lines) - Mixes cache utilities, database schema, FeedCache class, and clustering repository
- `fetcher.cr` (1058 lines) - Mixes favicon handling, feed fetching, and refresh loop logic
- `api_controller.cr` (813 lines) - Single controller handling all API routes

This refactoring is purely structural with zero functional changes.

## Goals / Non-Goals

**Goals:**
- Split each large file into focused modules under 400 lines each
- Maintain backward compatibility for all require statements
- Preserve all existing functionality without changes
- Improve code navigability and AI context efficiency

**Non-Goals:**
- No functional changes or bug fixes
- No API changes
- No performance optimizations
- No new features

## Decisions

### 1. Directory Structure Approach
**Decision:** Create subdirectories (`src/storage/`, `src/fetcher/`, `src/controllers/routes/`) with focused files.

**Rationale:** 
- Crystal allows requiring directories which auto-requires all `.cr` files
- Keeps related code together while enabling focused file navigation
- Alternative: Keep flat structure with numbered prefixes (rejected - harder to maintain)

### 2. FeedCache Class Location
**Decision:** Move `FeedCache` class to `src/storage/feed_cache.cr` as the main class, with helper functions in same file.

**Rationale:**
- FeedCache is 800+ lines and is the core storage abstraction
- Clustering database operations (LSH, signatures) extracted to separate `clustering_repo.cr`
- Database schema/migration functions extracted to `database.cr`

### 3. API Controller Split Strategy
**Decision:** Split by route groups with shared base controller.

**Structure:**
```
src/controllers/
├── base_controller.cr      # Shared logic (rate limiting, auth)
└── routes/
    ├── cluster_routes.cr   # /api/clusters
    ├── feed_routes.cr      # /api/feeds/*
    ├── config_routes.cr    # /api/config/*
    ├── admin_routes.cr     # /api/admin/*
    └── item_routes.cr      # /api/items/*
```

**Rationale:**
- Each route group can be read independently
- Athena supports multiple controllers mounting same routes
- Alternative: Single file with include modules (rejected - still large file)

### 4. Require Path Compatibility
**Decision:** Add `require` aliases in original file locations for backward compatibility.

```crystal
# src/storage.cr (new - thin require file)
require "./storage/*"

# src/fetcher.cr (new - thin require file)  
require "./fetcher/*"
```

**Rationale:**
- Existing code `require "./storage"` continues working
- No changes needed to other source files
- Alternative: Update all require statements (rejected - high risk, many changes)

### 5. FaviconCache Separation
**Decision:** Keep `FaviconCache` and `FaviconHelper` together in `src/fetcher/favicon.cr`.

**Rationale:**
- Tightly coupled - favicon cache is specific to favicon fetching
- ~200 lines combined - fits well in single focused file
- Feed fetching logic has no favicon dependencies

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Circular requires between new modules | Use forward declarations; split types into separate files if needed |
| Missing requires after split | Run `just nix-build` after each file split to catch errors |
| Global functions lost after move | Keep utility functions in their origin module or create shared utils file |
| Test failures from structural changes | Run full test suite after each major split |

## Migration Plan

1. **Phase 1 - storage.cr split:**
   - Create `src/storage/` directory
   - Extract database schema functions → `database.cr`
   - Extract clustering repository → `clustering_repo.cr`
   - Extract cache utilities → `cache_utils.cr`
   - Move FeedCache class → `feed_cache.cr`
   - Create thin `src/storage.cr` require file
   - Build and test

2. **Phase 2 - fetcher.cr split:**
   - Create `src/fetcher/` directory
   - Extract favicon logic → `favicon.cr`
   - Extract feed fetching → `feed_fetcher.cr`
   - Extract refresh loop → `refresh_loop.cr`
   - Create thin `src/fetcher.cr` require file
   - Build and test

3. **Phase 3 - api_controller.cr split:**
   - Create `src/controllers/routes/` directory
   - Extract base controller → `base_controller.cr`
   - Split routes by group into respective files
   - Update routing configuration if needed
   - Build and test

## Open Questions

None - straightforward structural refactoring with clear approach.

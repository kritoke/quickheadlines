## Why

Three Crystal source files exceed 700 lines (`storage.cr`: 1647, `fetcher.cr`: 1058, `api_controller.cr`: 813), making them difficult to navigate, understand, and maintain. Large files increase AI context usage and reduce code readability. Splitting these into focused modules improves maintainability, reduces cognitive load, and makes the codebase more AI-friendly.

## What Changes

- Split `src/storage.cr` into 4 focused modules:
  - `src/storage/cache_utils.cr` - Cache directory utilities, path resolution
  - `src/storage/database.cr` - Schema creation, migrations, integrity checks
  - `src/storage/feed_cache.cr` - FeedCache class with CRUD operations
  - `src/storage/clustering_repo.cr` - Clustering database operations (LSH, signatures)

- Split `src/fetcher.cr` into 3 focused modules:
  - `src/fetcher/favicon.cr` - FaviconHelper, FaviconCache, favicon fetching
  - `src/fetcher/feed_fetcher.cr` - Feed fetching and parsing logic
  - `src/fetcher/refresh_loop.cr` - Refresh loop, clustering integration

- Split `src/controllers/api_controller.cr` into route-focused files:
  - `src/controllers/routes/cluster_routes.cr` - `/api/clusters` endpoints
  - `src/controllers/routes/feed_routes.cr` - `/api/feeds/*` endpoints
  - `src/controllers/routes/config_routes.cr` - `/api/config/*` endpoints
  - `src/controllers/routes/admin_routes.cr` - `/api/admin/*` endpoints
  - `src/controllers/routes/item_routes.cr` - `/api/items/*` endpoints
  - `src/controllers/base_controller.cr` - Shared controller logic

## Capabilities

### New Capabilities
- `modular-storage`: Split storage operations into focused modules for cache utilities, database management, and clustering repository
- `modular-fetcher`: Split fetcher operations into focused modules for favicons, feed fetching, and refresh loops
- `modular-api-routes`: Split API controller into route-grouped modules

### Modified Capabilities
None - this is a pure refactoring with no functional changes.

## Impact

**Affected Code:**
- `src/storage.cr` → Split into `src/storage/` directory (4 files)
- `src/fetcher.cr` → Split into `src/fetcher/` directory (3 files)
- `src/controllers/api_controller.cr` → Split into `src/controllers/routes/` directory (6 files)

**Dependencies:**
- All files requiring `storage.cr`, `fetcher.cr`, or `api_controller.cr` will need updated require statements

**Systems:**
- No runtime behavior changes
- No API changes
- No database schema changes

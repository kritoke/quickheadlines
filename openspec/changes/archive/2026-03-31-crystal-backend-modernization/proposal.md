## Why

The Crystal backend suffers from architectural debt that makes it difficult to test, maintain, and extend. Global singletons pervade the codebase, a single controller exceeds 900 lines, time formatting is duplicated across 15+ locations, and the codebase inconsistently uses modules namespaces (`QuickHeadlines` vs `Quickheadlines`). Modernizing these patterns will reduce bugs, improve testability, and align the codebase with idiomatic Crystal 1.18 practices.

## What Changes

- **Split `ApiController`** (902 lines) into focused controllers: `FeedsController`, `TimelineController`, `ClusterController`, `AdminController`, `AssetController`, `ProxyController`
- **Eliminate global singletons**: Remove `@@instance` class variables from `FeedCache`, `DatabaseService`, `SocketManager`, `FeedFetcher`, replacing with proper Athena DI via `@[ADI::Register]` and constructor injection
- **Extract `DB_TIME_FORMAT` constant**: Replace 15+ occurrences of `"%Y-%m-%d %H:%M:%S"` with `Constants::DB_TIME_FORMAT`
- **Unify module naming**: Standardize all modules under `QuickHeadlines` (capital H), eliminating `Quickheadlines` inconsistencies
- **Adopt Crystal `Log` module**: Replace 60+ `STDERR.puts` calls with structured logging via `Log`
- **Convert free functions to module methods**: Move standalone functions like `load_config`, `validate_feed`, `refresh_all` into proper modules as `self.` methods
- **Consolidate schema initialization**: Eliminate duplicate `create_schema`/`run_migrations` calls across `DatabaseService`, `FeedCache`, and `storage/database.cr`
- **Add typed `rescue` clauses**: Replace bare `rescue` with typed exceptions throughout
- **Simplify `Utils.private_host?`**: Reduce 16-clause `||` chain with idiomatic Crystal using `IPAddress.private?`

## Capabilities

### New Capabilities
- `di-container`: Full dependency injection via Athena's ADI framework, replacing all manual singleton patterns
- `structured-logging`: Unified logging via Crystal's `Log` module with contextual metadata

### Modified Capabilities
- (none - this is a pure refactoring with no behavioral changes to user-facing capabilities)

## Impact

### Code Structure
- `src/controllers/api_controller.cr` → split into 6 controller files in `src/controllers/`
- `src/models.cr` → `StateStore`, `FeedCache`, `FEED_CACHE` singleton moved to proper modules
- `src/services/database_service.cr` → DI-registered service, removes `@@instance`
- `src/services/feed_service.cr` → DI-registered, methods refactored
- `src/services/clustering_service.cr` → DI-registered, `@@instance` removed
- `src/fetcher/feed_fetcher.cr` → DI-registered, free functions become module methods
- `src/fetcher/refresh_loop.cr` → free functions become module methods
- `src/storage/feed_cache.cr` → singleton removed, DI-based initialization
- `src/storage/database.cr` → `create_schema` centralized
- `src/config/loader.cr` → functions become `ConfigLoader` module methods
- `src/config/validator.cr` → functions become `ConfigValidator` module methods
- `src/utils.cr` → `private_host?` simplified, logging modernized
- `src/quickheadlines.cr` → entry point cleanup, single `ATH.run` call
- `src/application.cr` → initialization consolidated, guard removed

### No Breaking Changes
This refactoring has **zero user-facing API changes**. All HTTP endpoints, WebSocket behavior, database schemas, and configuration file formats remain identical. Only internal implementation patterns change.

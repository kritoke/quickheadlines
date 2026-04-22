## Why

The backend accumulated architectural debt from incremental development: a dual DI pattern accepting both `DatabaseService | DB::Database` that was never resolved, `AdminController` executing raw SQL that bypasses the store/repository layer, two independent refresh guards that can diverge, config hot-reload that skips validation, missing rate limiting on several public endpoints, and a top-level function that creates N service instances per refresh cycle. These issues make the architecture fragile and inconsistent.

## What Changes

- Standardize on `DatabaseService` as the sole DI type for repositories and services, removing the `DB::Database` union
- Move `AdminController` raw SQL operations through stores/repositories
- Unify refresh guards to use only `StateStore.refreshing?` with proper error recovery
- Fix config hot-reload in `RefreshLoop` to use `load_validated_config`
- Add `check_rate_limit!` to unprotected public GET endpoints
- Refactor `compute_item_cluster` top-level function to reuse a single `ClusteringService` instance

## Capabilities

### New Capabilities
- `backend-architecture-cleanup`: Consistent DI, proper abstraction layers, unified state tracking, validated config reload, comprehensive rate limiting

### Modified Capabilities

## Impact

- **Repositories**: `repository_base.cr` (remove DB::Database union), `cluster_repository.cr`
- **Services**: `clustering_service.cr` (remove DB::Database union), `database_service.cr`
- **Controllers**: `admin_controller.cr` (remove raw SQL, add rate limiting), `config_controller.cr`, `tabs_controller.cr`, `cluster_controller.cr`, `asset_controller.cr`
- **Fetcher**: `refresh_loop.cr` (validated config reload, unified refresh guard, single ClusteringService instance)
- **Models**: `models.cr` (remove unused REFRESH_IN_PROGRESS if appropriate)
- **Config**: `loader.cr` (may need reload-specific validation path)

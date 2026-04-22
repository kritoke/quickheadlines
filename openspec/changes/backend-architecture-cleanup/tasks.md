## 1. DI Pattern Standardization

- [x] 1.1 Remove `DB::Database` union from `RepositoryBase`, accept only `DatabaseService`
- [x] 1.2 Remove case/when dispatch in `RepositoryBase#initialize`
- [x] 1.3 Remove `DB::Database` union from `ClusteringService`, accept only `DatabaseService`
- [x] 1.4 Remove case/when dispatch in `ClusteringService#initialize`
- [x] 1.5 Update all callers passing `DB::Database` to pass `DatabaseService` instead (AppBootstrap, FaviconSyncService, RefreshLoop, etc.)

## 2. Admin Raw SQL Removal

- [x] 2.1 Add `cleanup_orphaned_items` method to appropriate store/repository
- [x] 2.2 Update `AdminController#handle_clear_cache` to use store methods only
- [x] 2.3 Update `AdminController#handle_cleanup_orphaned` to use store method
- [x] 2.4 Remove all `cache.db.exec` and `cache.db.query` calls from AdminController

## 3. Refresh Guard Unification

- [x] 3.1 Remove `REFRESH_IN_PROGRESS = Atomic(Bool).new(false)` from refresh_loop.cr
- [x] 3.2 Replace `REFRESH_IN_PROGRESS` usage with `StateStore.refreshing?` / `StateStore.refreshing=`
- [x] 3.3 Wrap refresh body in `begin/ensure` to guarantee `StateStore.refreshing = false`

## 4. Config Hot-Reload Validation

- [x] 4.1 Change refresh loop config reload to use `load_validated_config` instead of `load_config`
- [x] 4.2 Add error handling: log validation failure and keep current config on invalid reload

## 5. Rate Limiting Coverage

- [x] 5.1 Add `check_rate_limit!` to `ConfigController#config`
- [x] 5.2 Add `check_rate_limit!` to `TabsController#tabs`
- [x] 5.3 Add `check_rate_limit!` to `ClusterController#clusters`
- [x] 5.4 Add `check_rate_limit!` to `ClusterController#cluster_items`
- [x] 5.5 Add `check_rate_limit!` to `AssetController#favicon_png`

## 6. ClusteringService Instance Reuse

- [x] 6.1 Remove top-level `compute_item_cluster` function from refresh_loop.cr
- [x] 6.2 Create single `ClusteringService` instance at start of refresh cycle
- [x] 6.3 Pass instance through to clustering operations instead of creating per-item

## 7. Verification

- [x] 7.1 Run `just nix-build` and verify compilation succeeds
- [x] 7.2 Run `nix develop . --command crystal spec` and verify tests pass

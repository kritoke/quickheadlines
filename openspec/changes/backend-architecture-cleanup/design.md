## Context

The backend grew organically with several architectural patterns that were introduced incrementally but never reconciled:

1. **Dual DI**: `RepositoryBase` and `ClusteringService` accept `DatabaseService | DB::Database` via case/when dispatch. Some callers pass `DatabaseService`, others pass `DB::Database` directly.
2. **Raw SQL bypass**: `AdminController` reaches through to `cache.db` for `handle_clear_cache` and `handle_cleanup_orphaned` instead of using the store/repository layer.
3. **Dual refresh guards**: `REFRESH_IN_PROGRESS = Atomic(Bool).new(false)` in refresh_loop.cr and `StateStore.refreshing?` in models.cr track the same state independently and can diverge.
4. **Config reload skips validation**: Startup uses `load_validated_config` but hot-reload uses `load_config` (no validation).
5. **Missing rate limiting**: `ConfigController`, `TabsController`, `ClusterController`, and `AssetController#favicon_png` lack `check_rate_limit!`.
6. **N-instance creation**: `compute_item_cluster` top-level function creates a new `ClusteringService` per item instead of reusing one.

## Goals / Non-Goals

**Goals:**
- Single DI pattern: all repositories and services accept `DatabaseService`
- All data operations go through stores/repositories, not raw SQL in controllers
- Single source of truth for refresh state
- Config hot-reload validates before applying
- All public API endpoints have rate limiting
- Clustering service is instantiated once per refresh cycle

**Non-Goals:**
- Changing the refresh loop's concurrency model
- Adding new rate limiting rules or thresholds
- Refactoring the config validation logic itself
- Changing how `StateStore` works

## Decisions

### D1: Standardize on DatabaseService for DI

`DatabaseService` wraps `DB::Database` and provides additional lifecycle management. All repositories and services SHALL accept `DatabaseService` only. Remove the `DB::Database` union type and case/when dispatch.

**Rationale**: `DatabaseService` is already the primary type used by `ApiBaseController`. The `DB::Database` path was likely a legacy shortcut.

### D2: Add store methods for admin operations

Add `cleanup_orphaned_items` to an appropriate store (likely `CleanupStore` or `FeedCache`). `AdminController` calls store methods, never touches `cache.db` directly.

### D3: Remove REFRESH_IN_PROGRESS, use StateStore only

Remove the `REFRESH_IN_PROGRESS = Atomic(Bool)` from `refresh_loop.cr`. Use `StateStore.refreshing?` / `StateStore.refreshing=` exclusively. Wrap the refresh body in `begin/ensure` to guarantee `StateStore.refreshing = false` on any exit path.

### D4: Config reload uses load_validated_config

The refresh loop's config reload SHALL call `load_validated_config` instead of `load_config`. If validation fails, log the error and keep the current config.

### D5: Add rate limiting to unprotected endpoints

Add `check_rate_limit!` calls to: `ConfigController#config`, `TabsController#tabs`, `ClusterController#clusters`, `ClusterController#cluster_items`, `AssetController#favicon_png`.

### D6: Instantiate ClusteringService once per refresh cycle

Instead of the top-level `compute_item_cluster` function creating N instances, pass a single `ClusteringService` instance through the refresh pipeline.

## Risks / Trade-offs

- **[DI change breaks callers]** → All callers must be updated in a single pass. Compiler catches missed references.
- **[StateStore.refreshing divergence risk]** → Using begin/ensure mitigates the risk of the flag being left true after a crash.
- **[Config validation on reload could reject valid configs]** → Use the same validation logic as startup. If a config was valid at startup but fails reload, it indicates a real issue.
- **[Rate limiting on new endpoints could affect legitimate use]** → Use the same limits as existing rate-limited endpoints.

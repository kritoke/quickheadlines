## Why

The `src/api.cr` file (~600 lines) contains legacy code that is not connected to the Athena routing system. Methods like `API.handle_timeline`, `API.handle_feeds`, and `API.handle_version` are defined but never registered as routes. This dead code:
- Causes confusion for developers reading the codebase
- Inflates compile times with unused code
- Makes the codebase harder to maintain

The actual routing is handled exclusively by `controllers/api_controller.cr` using Athena's `@[ARTA::Get]` annotations.

## What Changes

- **Remove** `src/api.cr` entirely (except response DTOs that ARE used by `StoryService`)
- **Remove** `StateStore.all_timeline_items_impl` method (only used by dead code path)
- **Remove** `AppState.all_timeline_items` method (only used by dead code path)
- **Verify** no remaining references to removed code

## Capabilities

### New Capabilities
None - this is a cleanup/removal task.

### Modified Capabilities
None - no requirement changes.

## Impact

- **Removed Files**: `src/api.cr` (partial - keeping only response DTOs)
- **Modified Files**: `src/models.cr` (removing `all_timeline_items_impl` and `all_timeline_items`)
- **No API changes**: The actual timeline, feeds, and version endpoints remain unchanged
- **No breaking changes**: Production traffic uses `api_controller.cr` routes only

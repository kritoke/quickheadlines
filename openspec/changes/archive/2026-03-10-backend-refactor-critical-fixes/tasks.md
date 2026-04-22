## 1. Constants Centralization

- [x] 1.1 Create `src/constants.cr` with `Constants` module
- [x] 1.2 Move `CONCURRENCY = 8` from `src/utils.cr` to constants
- [x] 1.3 Move `CACHE_RETENTION_HOURS = 168` from `src/storage/cache_utils.cr` to constants
- [x] 1.4 Move `CACHE_RETENTION_DAYS = 7` from `src/storage/cache_utils.cr` to constants
- [x] 1.5 Update all files to import Constants module
- [x] 1.6 Verify build succeeds

## 2. Database Schema Consolidation

- [x] 2.1 Create `src/storage/schema.cr` with shared `SCHEMA_SQL` constant
- [x] 2.2 Update `src/storage/database.cr` to use shared schema
- [x] 2.3 Update `src/services/database_service.cr` to use shared schema
- [x] 2.4 Verify database still creates correctly on fresh start
- [x] 2.5 Verify build succeeds

## 3. Timeline Performance Fix

- [x] 3.1 Audit `src/api.cr` for timeline query patterns
- [x] 3.2 Identify any per-item cluster queries
- [x] 3.3 Replace with batch query using DatabaseService
- [x] 3.4 Verify timeline endpoint works correctly
- [x] 3.5 Run Crystal tests
- [x] 3.6 Verify build succeeds

## 4. TimelineItem Consolidation

- [x] 4.1 Identify all usages of `TimelineItem` from `src/repositories/story_repository.cr`
- [x] 4.2 Update code to use `TimelineItem` from `src/models.cr`
- [x] 4.3 Remove duplicate struct from `src/repositories/story_repository.cr`
- [x] 4.4 Verify build succeeds

## 5. AppBootstrap Refactoring

- [x] 5.1 Create `src/services/app_bootstrap.cr` with `AppBootstrap` class
- [x] 5.2 Extract initialization logic from `src/application.cr`
- [x] 5.3 Separate `initialize_services` from `start_background_tasks`
- [x] 5.4 Make background task intervals configurable via Config
- [x] 5.5 Update `src/application.cr` to use AppBootstrap
- [x] 5.6 Verify server starts correctly
- [x] 5.7 Verify build succeeds

## 6. WebSocket Heartbeat

- [x] 6.1 Add ping mechanism to WebSocket server (30s interval)
- [x] 6.2 Track `last_pong_time` per connection
- [x] 6.3 Add pong handler to receive client responses
- [x] 6.4 Update janitor to clean up stale connections (60s timeout)
- [x] 6.5 Test WebSocket connections stay alive correctly
- [x] 6.6 Verify build succeeds

## 7. Error Handling Improvements

- [x] 7.1 Add logging to silent catch blocks in `src/storage/database.cr`
- [x] 7.2 Review other files for silent exception handling
- [x] 7.3 Verify build succeeds

## 8. Final Verification

- [x] 8.1 Run `just nix-build` - MUST succeed
- [x] 8.2 Run Crystal tests: `nix develop . --command crystal spec`
- [x] 8.3 Run frontend tests: `cd frontend && npm run test`
- [x] 8.4 Run Ameba lint: `nix develop . --command ameba --fix`
- [x] 8.5 Verify git status shows clean (only expected changes)

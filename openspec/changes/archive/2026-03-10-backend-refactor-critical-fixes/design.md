## Context

QuickHeadlines is a Crystal-based RSS reader with a Svelte frontend. The backend suffers from:

1. **Timeline N+1 Problem**: The `/api/timeline` endpoint fetches cluster information for each item individually, causing O(n) database queries. With 500 items, this means 501 round-trips to SQLite.

2. **Duplicate Schema**: Database table definitions exist in both `src/storage/database.cr` and `src/services/database_service.cr`. This creates risk of schema drift during development.

3. **Scattered Constants**: Magic numbers like `CONCURRENCY = 8` and `CACHE_RETENTION_*` are defined in multiple files with no central source of truth.

4. **Blob Initialization**: `src/application.cr` has 130+ lines of initialization code with 5+ background fibers spawned inline, making it hard to test and modify.

5. **Duplicate Models**: `TimelineItem` struct is defined twice in `src/models.cr` and `src/repositories/story_repository.cr`.

## Goals / Non-Goals

**Goals:**
- Fix timeline endpoint to use single query with JOINs for cluster data
- Single source of truth for database schema
- Centralized constants file
- Structured application bootstrap with configurable intervals
- Clean up duplicate model definitions
- Add WebSocket heartbeat for connection health

**Non-Goals:**
- No API contract changes (backward compatible)
- No database migration strategy changes
- No external dependency additions
- No authentication/authorization changes

## Decisions

### D1: Single Database Schema Module
**Decision**: Extract schema to `src/storage/schema.cr` as SQL constant, imported by both.

**Rationale**: Crystal doesn't have a great way to share constants across files without modules. Creating a dedicated schema module with versioned SQL ensures both locations use identical DDL.

**Alternative Considered**: Use a single schema file and import everywhere. Rejected because `DatabaseService` needs migrations which are already in place there.

### D2: Timeline Query Fix - Use Existing DatabaseService Method
**Decision**: The `DatabaseService#get_timeline_items` already has the correct JOIN query (lines 168-244). Fix the API layer to use it properly instead of adding per-item queries.

**Rationale**: Leverages existing well-written code instead of rewriting. The issue is in the API/DTO conversion layer, not the query itself.

### D3: Constants Centralization
**Decision**: Create `src/constants.cr` with all magic numbers. Use a Crystal module to avoid namespace pollution.

```crystal
module Constants
  CONCURRENCY = 8
  CACHE_RETENTION_HOURS = 168
  CACHE_RETENTION_DAYS = 7
end
```

**Rationale**: Simple, idiomatic Crystal. Using a module makes it easy to `include` or reference as `Constants::CONCURRENCY`.

### D4: App Bootstrap Refactoring
**Decision**: Extract initialization to `AppBootstrap` class that:
- Takes Config as constructor dependency
- Has separate `initialize_services` and `start_background_tasks` methods
- Background task intervals come from Config, not hardcoded

```crystal
class AppBootstrap
  def initialize(@config : Config)
  end
  
  def initialize_services
    # DB, cache, favicon storage init
  end
  
  def start_background_tasks
    # Spawn all background fibers with configurable intervals
  end
end
```

**Rationale**: Makes it testable (can instantiate without spawning fibers) and configurable. Allows changing refresh intervals without code changes.

### D5: TimelineItem Consolidation
**Decision**: Keep `record TimelineItem` in `src/models.cr` (line 5), remove the class version from `src/repositories/story_repository.cr` (line 274).

**Rationale**: Records are immutable and idiomatic for DTOs. The class version was likely an intermediate step that became redundant.

### D6: WebSocket Heartbeat
**Decision**: Add ping/pong mechanism:
- Server sends PING every 30 seconds
- Client must respond with PONG within 10 seconds
- Track `last_pong_time` per connection
- Clean up connections with missed heartbeats

**Rationale**: Standard WebSocket health check pattern. Prevents stale connections from consuming resources.

## Risks / Trade-offs

- **[Risk] Schema change during migration** → **Mitigation**: Both files will import from same `schema.cr`. Old code still works during transition.

- **[Risk] Breaking existing timeline behavior** → **Mitigation**: The new query produces identical output, just faster. Will verify with existing tests.

- **[Risk] AppBootstrap refactor breaks startup** → **Mitigation**: Keep `application.cr` working, refactor incrementally. Test each background task separately.

- **[Risk] Constants file introduces conflicts** → **Mitigation**: Use module namespace to avoid collision. Replace references one file at a time.

## Migration Plan

1. Create `src/constants.cr` and update all references
2. Create `src/storage/schema.cr` and update both database files
3. Verify timeline still works (should be transparent fix)
4. Refactor `application.cr` → `AppBootstrap`
5. Remove duplicate `TimelineItem`
6. Add WebSocket heartbeat
7. Run full test suite, verify `just nix-build` succeeds

## Open Questions

- Should we use compile-time constants (`VERSION`) or runtime config for intervals?
  - **Answer**: Keep runtime config from `Config` for flexibility
- Do we need to version the schema?
  - **Answer**: No, SQLite migrations in `DatabaseService` handle versioning

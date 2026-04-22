## Context

The Crystal backend at `/workspaces/quickheadlines/src` is architecturally inconsistent despite following a nominally layered architecture (entities, repositories, services, controllers). The codebase is in a mid-refactor state: some types use Athena's DI framework (`@[ADI::Register]`), while most rely on manual singleton patterns (`@@instance`). The `ApiController` at 902 lines violates single responsibility. Time formatting literals are duplicated 15+ times. Module naming is inconsistent (`QuickHeadlines` vs `Quickheadlines`).

Constraints:
- Crystal 1.18.2 only (no `Time::Instant`)
- Athena framework 0.21.x
- SQLite via `crystal-sqlite3`
- No ORM (raw SQL)
- Must maintain full backward compatibility (no API changes)

## Goals / Non-Goals

**Goals:**
- Eliminate all `@@instance` singleton patterns, replacing with proper DI
- Split the 902-line `ApiController` into 6 focused controllers
- Extract `DB_TIME_FORMAT` constant and eliminate duplication
- Unify module naming to `QuickHeadlines` (capital H)
- Adopt Crystal's `Log` module for structured logging
- Move free functions into modules as `self.` methods
- Consolidate database schema initialization

**Non-Goals:**
- No user-facing API changes
- No database schema changes
- No new dependencies
- No performance optimization (debt reduction only)
- Frontend Svelte code is out of scope

## Decisions

### Decision 1: Use Athena DI Consistently

**Choice:** Register all major services with `@[ADI::Register]` and inject via constructors. Remove all `@@instance` class variables.

**Rationale:** The codebase already uses `@[ADI::Register]` annotations on `DatabaseService`, `FeedCache`, and `ErrorRenderer`, but doesn't actually use constructor injection - the controller manually calls `.instance`. Making DI the sole mechanism removes hidden coupling.

**Alternatives considered:**
- *Service locator pattern*: Anti-pattern in DI contexts, creates hidden dependencies
- *Manual DI with factory functions*: Works but doesn't integrate with Athena's lifecycle management
- *Keep singletons*: Technical debt that perpetuates testability problems

### Decision 2: Controller Split Strategy

**Choice:** Split `ApiController` into 6 controllers by domain concern, each in its own file under `src/controllers/`.

**Rationale:** Natural boundary based on HTTP endpoint groupings. Athena supports multiple controllers with auto-routing.

**Split:**
| New Controller | Responsibilities |
|---|---|
| `FeedsController` | `/api/feeds`, `/api/feed_more`, `/api/tabs` |
| `TimelineController` | `/api/timeline` |
| `ClusterController` | `/api/clusters`, `/api/clusters/:id/items` |
| `AdminController` | `/api/admin`, `/api/cluster` (POST) |
| `AssetController` | `/favicon.png`, `/sun-icon.svg`, `/moon-icon.svg`, `/home-icon.svg`, `/timeline-icon.svg`, `/favicons/{hash}.{ext}` |
| `ProxyController` | `/proxy_image` |

### Decision 3: Logging Migration

**Choice:** Replace all `STDERR.puts "[#{Time.local}] ..."` with `Log.for("quickheadlines").info { "..." }` using Crystal's built-in `Log` module.

**Rationale:** Structured logging with source context, configurable backends, proper log levels. Crystal 1.18 has a mature `Log` stdlib.

**Format change:**
```crystal
# Before
STDERR.puts "[#{Time.local}] Loaded #{feeds.size} feeds from cache"

# After
Log.for("quickheadlines.cache").info { "Loaded #{feeds.size} feeds from cache" }
```

### Decision 4: Time Format Centralization

**Choice:** Add `DB_TIME_FORMAT = "%Y-%m-%d %H:%M:%S"` to `Constants` module and use it everywhere time is formatted/parsed for SQLite storage.

**Rationale:** Eliminates duplication and ensures consistent parsing. ISO 8601 would be better but requires SQLite date storage migration.

### Decision 5: Module Naming

**Choice:** Rename all `Quickheadlines` (lowercase h) to `QuickHeadlines` (capital H) to match `QuickHeadlines::Application`.

**Files affected:** All files declaring `module Quickheadlines` → `module QuickHeadlines`.

### Decision 6: Free Function Migration

**Choice:** Convert free functions to module methods (using `self.` or `def self.method`).

**Pattern:**
```crystal
# Before
def load_config(path : String) : Config
  # ...
end

# After
module QuickHeadlines::ConfigLoader
  def self.load(path : String) : Config
    # ...
  end
end
```

**Files affected:** `config/loader.cr`, `config/validator.cr`, `fetcher/feed_fetcher.cr`, `fetcher/refresh_loop.cr`, `storage/feed_cache.cr`

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| Breaking DI at runtime if service dependencies aren't registered correctly | Run existing test suite after each change; use `crystal spec` |
| Controller split changes URL routing | Athena uses annotations, routing unchanged |
| `Log` output goes to stdout by default, not stderr | Configure `Log` backend in `application.cr` initialization |
| Module rename could break require statements | Use incremental renames, testing after each |
| Removing global `FEED_CACHE` breaks lazy initialization | Ensure DI container initializes `FeedCache` before `FeedFetcher` |

## Migration Plan

**Phase 1: Foundation (no behavior change)**
1. Add `DB_TIME_FORMAT` constant to `Constants`
2. Replace all time format literals with constant
3. Add typed `rescue` clauses throughout

**Phase 2: Module Organization**
4. Rename `module Quickheadlines` → `module QuickHeadlines` in all files
5. Move free functions to modules (`ConfigLoader`, `ConfigValidator`, `FeedCacheManager`, `RefreshLoop`)

**Phase 3: DI Migration**
6. Register `FeedCache`, `FeedFetcher`, `DatabaseService`, `ClusteringService`, `StoryService` with Athena DI
7. Update controllers to accept injected services via constructor
8. Remove all `@@instance` class variables

**Phase 4: Controller Split**
9. Extract `AssetController` from `ApiController`
10. Extract `ProxyController` from `ApiController`
11. Extract `AdminController` from `ApiController`
12. Extract `ClusterController` from `ApiController`
13. Extract `TimelineController` from `ApiController`
14. Rename remaining `ApiController` → `FeedsController`

**Phase 5: Logging**
15. Replace `STDERR.puts` with `Log` calls throughout

**Rollback:** Each phase is independently deployable. No database migration required. Git revert to last working phase if issues arise.

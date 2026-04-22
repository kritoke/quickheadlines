## Context

The Crystal backend (81 files, ~8,795 lines) has accumulated technical debt from iterative development. Two legacy storage modules (`ClusteringRepository`, `CleanupRepository`) were superseded by class-based stores but never removed. The `FeedCache` facade in `src/storage/feed_cache.cr` wraps three sub-stores with 25+ pass-through delegation methods. Method naming conventions drift toward verbosity (38 methods with 4+ word names). Common patterns (time parsing, DB init, placeholder generation) are repeated across repositories.

The project MUST maintain Crystal 1.18.2 compatibility for FreeBSD deployment.

## Goals / Non-Goals

**Goals:**
- Remove all dead/unused code without breaking any tests or builds
- Reduce all method names to 3 words or fewer
- Extract shared patterns into reusable helpers to eliminate DRY violations
- Split any files over 400 lines into focused, cohesive modules
- Apply idiomatic Crystal patterns (try, .presence, safe navigation)

**Non-Goals:**
- No new features or API changes
- No database schema changes
- No dependency additions or upgrades
- No frontend changes
- No performance optimization (separate concern)
- Files between 300-400 lines are acceptable if logically cohesive (e.g., clustering_store.cr after dead code removal)

## Decisions

### 1. Delete dead modules entirely vs. deprecate
**Decision:** Delete immediately.
**Rationale:** `ClusteringRepository` has zero imports in the entire codebase. `CleanupRepository` is only referenced in one spec file. No external consumers exist. Keeping dead code adds maintenance burden and confuses new contributors.

### 2. RepositoryBase abstract class vs. module mixin
**Decision:** Abstract class `QuickHeadlines::Repositories::RepositoryBase`.
**Rationale:** All 4 repositories (FeedRepository, StoryRepository, ClusterRepository, HeatMapRepository) share identical `initialize(db_or_service)` logic and all hold a `@db : DB::Database`. An abstract class provides both shared constructor and a home for future shared helpers (like `parse_db_time`). Crystal's single inheritance is fine here since no repository needs to inherit from anything else.

### 3. CacheUtils helpers vs. shard/extension
**Decision:** Extend existing `QuickHeadlines::CacheUtils` module.
**Rationale:** `CacheUtils` already exists at `src/storage/cache_utils.cr` (133 lines) and is already imported by storage modules. Adding `parse_db_time`, `placeholders`, and similar utilities there is the path of least resistance. No new files needed for these small helpers.

### 4. FeedCache facade pattern — keep or flatten
**Decision:** Keep facade but expose sub-stores via getters for direct access where needed.
**Rationale:** The facade provides a clean DI surface for controllers. Removing it would require injecting 3-4 separate stores into every controller. Instead, we keep `FeedCache` but allow services that need direct store access (like `ClusteringService`) to use `cache.clustering_store` directly, reducing unnecessary wrapper methods.

### 5. Method renaming strategy
**Decision:** Rename aggressively to 2-3 words. Use Crystal naming conventions (snake_case, verb-noun for actions, noun for accessors).
**Rationale:** Consistent short names reduce line length, improve readability, and match Crystal stdlib conventions. Getter-like methods drop `get_` prefix (Crystal convention). `find_by_*` methods returning `Result` types drop the `_result` suffix (the type conveys the return semantics).

### 6. Time.monotonic usage
**Decision:** Keep as-is.
**Rationale:** `Time.monotonic` is compatible with Crystal 1.18.2. The deprecation in 1.19.x produces warnings only, not errors. Addressing it now would be premature — it would require a different API (`Time::Span`-based tracking).

## Risks / Trade-offs

- **[Renaming breaks call sites]** → Every rename requires updating all callers. Mitigation: use `grep` to find all usages before renaming; compile after each batch.
- **[RepositoryBase introduces coupling]** → All repositories now share a base class. Mitigation: keep base class minimal (only constructor + shared helpers); no business logic in base.
- **[Facade method removal changes DI surface]** → If callers depend on delegation methods like `cache.get_item_title`, removing them breaks compilation. Mitigation: keep facade methods for now; mark for gradual deprecation by having callers use direct store access.
- **[Dead code removal could have hidden dependencies]** → Static analysis shows zero imports, but runtime `require` could exist. Mitigation: compile check after each deletion.

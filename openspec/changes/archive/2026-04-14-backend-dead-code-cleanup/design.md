## Context

The Crystal backend has accumulated ~760 lines of dead code across ~20 files. A `crystal tool unreachable` analysis confirmed every item has zero runtime callers. The dead code falls into three categories:

1. **Abandoned architecture migration**: `Result(T, E)` type system, `FeedService`, entity/repository patterns that were scaffolded but never wired to controllers
2. **Unused utilities**: Global functions, DTOs, models, and methods that were superseded or made redundant
3. **Stubs and empty shells**: `feed_state.cr` (empty module), `repopulate_database` (no-op), unused shard dependency

The heat map system is intentionally preserved as a future feature.

## Goals / Non-Goals

**Goals:**
- Remove all code confirmed unreachable by `crystal tool unreachable` and grep analysis
- Remove unused `crimage` shard dependency
- Clean up `application.cr` require statements
- Maintain zero behavior change — all API endpoints work identically after cleanup

**Non-Goals:**
- Refactoring the dual model system (`models.cr` vs `entities/`) — deferred to Phase 6
- Migrating JSON::Serializable DTOs to ASR::Serializable — deferred to Phase 2
- Implementing the heat map system — preserved as future work
- Deduplicating logic (MIME types, cache dirs, IP extraction) — deferred to Phase 4
- Fixing `ErrorRenderer` dead match branches — deferred to Phase 5

## Decisions

### D1: Verify with `just nix-build` after each batch of deletions
**Rationale**: BakedFileSystem embeds assets at compile time. Incremental builds with verification catch any accidental dependency removals early.
**Alternative**: Delete everything at once and fix compile errors — riskier, harder to isolate issues.

### D2: Remove entire files before trimming methods from live files
**Rationale**: Deleting whole files (e.g., `result.cr`, `feed_service.cr`) is safer and easier to verify than surgical method removal from files that are still in use.
**Alternative**: Mixed approach — rejected for clarity.

### D3: Remove `*_result` methods from FeedRepository and FeedCache
**Rationale**: These are the last consumers of the dead `Result` type. Removing them first makes `result.cr` a clean delete with no dependents.

### D4: Keep `entities/`, `domain/items.cr`, and live repository methods
**Rationale**: `StoryRepository.find_timeline_items()` and `ClusterRepository.find_all()` are actively called. The entity types they return (`Entities::Story`, `Entities::Cluster`, `Domain::TimelineEntry`) must stay. Full entity alignment is Phase 6.

## Risks / Trade-offs

- **[Risk] Hidden runtime dependency** → Mitigation: `crystal tool unreachable` is exhaustive for compile-time reachability. Runtime reflection is not used in this codebase. Build verification with `just nix-build` catches any missed requires.
- **[Risk] Test breakage** → Mitigation: Run `nix develop . --command crystal spec` after each batch. The dead code has no callers, so tests should not reference it.

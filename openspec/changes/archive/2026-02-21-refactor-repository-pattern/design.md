## Context

### Current State
The codebase has a monolithic architecture where:
1. `ApiController` contains raw SQL queries (`get_clusters_from_db`)
2. `DatabaseService` mixes connection management with query logic
3. `FeedCache` combines in-memory caching with database persistence
4. `ClusteringService` directly queries the database
5. Frontend Svelte components lack semantic metadata for AI agent interaction

### Architecture Violations Found
- Controller → Database directly (bypasses Service/Repository)
- Controller → FeedCache directly (bypasses Service layer)
- Raw SQL in Controllers violates layered architecture

### Constraints
- Must maintain existing API contracts (no breaking changes)
- Crystal 1.18.2 required for FreeBSD compatibility
- Athena framework for HTTP layer
- SQLite for persistence

### Stakeholders
- Development team maintaining the codebase
- Future AI agents that will interact with the DOM

## Goals / Non-Goals

**Goals:**
1. Implement Repository pattern for Feed, Story, Cluster entities
2. Create Service layer with business logic
3. Remove all raw SQL from Controllers
4. Refactor FeedCache to pure in-memory cache
5. Add `data-name` semantic attributes to Svelte components

**Non-Goals:**
- No API contract changes
- No database migration (keep existing schema)
- No new external dependencies
- Not implementing authentication/authorization

## Decisions

### D1: Repository Method Placement
**Decision:** Place repositories in `src/repositories/` with methods that mirror database operations.

**Rationale:** Clean separation of concerns. Repositories handle persistence, Services handle business logic, Controllers handle HTTP only.

**Alternatives Considered:**
- Place repository methods in existing entity classes → Violates Single Responsibility
- Use Athena's built-in repository pattern → Not mature enough for our needs

### D2: FeedCache Refactoring Strategy
**Decision:** Strip FeedCache of all SQL, keep only in-memory cache with TTL.

**Rationale:** FeedCache name suggests caching behavior, not persistence. Separation allows independent testing and caching strategies.

**Alternatives Considered:**
- Keep FeedCache as-is → Maintains status quo but violates architecture
- Create entirely new cache class → More work, same outcome

### D3: Service Layer Creation
**Decision:** Create FeedService and StoryService that wrap Repository calls with business logic.

**Rationale:** Controllers should not contain business logic. Services orchestrate multiple repositories and contain domain logic.

**Alternatives Considered:**
- Controllers call repositories directly → Less abstraction, harder to test
- Use dependency injection throughout → Over-engineering for this codebase size

### D4: Semantic Metadata Pattern
**Decision:** Add `data-name` attribute to primary layout and interactive elements.

**Rationale:** AI agents need stable selectors. CSS classes change frequently; semantic attributes provide stable DOM hooks.

**Alternatives Considered:**
- Use data-testid → Too generic, no semantic meaning
- Use ARIA roles → Not sufficient for agent targeting

## Risks / Trade-offs

### R1: Breaking Existing Functionality
**Risk:** Refactoring may introduce bugs in existing behavior.

**Mitigation:** Extensive testing after each layer change. Keep API contracts unchanged.

### R2: Performance Regression
**Risk:** Additional abstraction layers may impact latency.

**Mitigation:** Repository methods are thin wrappers. No performance impact expected.

### R3: Scope Creep
**Risk:** May try to fix other issues during refactor.

**Mitigation:** Stick strictly to architecture refactor. Log other issues separately.

### T1: Trade-off - Development Time vs Clean Architecture
**Decision:** Invest time now for long-term maintainability.

---

## Migration Plan

### Phase 1: Repository Layer
1. Implement FeedRepository with all Feed persistence methods
2. Implement StoryRepository with all Story persistence methods  
3. Implement ClusterRepository (extract from ApiController)
4. Run tests

### Phase 2: Service Layer
1. Create FeedService wrapping FeedRepository
2. Create StoryService wrapping StoryRepository
3. Refactor ClusteringService to use ClusterRepository
4. Run tests

### Phase 3: Controller Refactor
1. Update ApiController to use Services
2. Remove raw SQL methods from ApiController
3. Run full integration tests

### Phase 4: FeedCache Refactor
1. Strip SQL from FeedCache
2. Verify caching still works
3. Run tests

### Phase 5: Frontend Metadata
1. Add data-name to all Svelte components
2. Verify no visual regressions

### Rollback Strategy
Each phase tested before proceeding. If issues found, revert to previous working state using git.

## Open Questions

1. **Q:** Should HeatMapRepository be refactored similarly?
   **A:** Yes, apply same pattern for consistency.

2. **Q:** How to handle the singleton pattern currently used?
   **A:** Keep singleton for DatabaseService and FeedCache. Inject via constructor.

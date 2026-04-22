## Context

QuickHeadlines is a Crystal/Athena-based RSS feed aggregator with a Svelte frontend. The backend currently suffers from:

- **Global State Chaos**: Multiple competing state systems (AppState singleton in `src/models.cr`, class variables `@@instance` for DatabaseService, FeedFetcher, SocketManager, RateLimiter, etc.)
- **Inconsistent Error Handling**: No standardized error types or HTTP status mapping; errors caught with rescue blocks but not properly propagated
- **Zero Test Coverage**: No test infrastructure exists
- **Memory Leaks**: Unbounded caches in FeedCache, ColorExtractor, FaviconStorage; no connection pooling
- **N+1 Query Problems**: No pagination on API endpoints, no query optimization
- **Security Gaps**: No centralized input validation, inconsistent URL sanitization
- **Incomplete Rate Limiting**: Admin endpoints bypass rate limiting
- **Configuration Scattered**: Validation happens in multiple places

## Goals / Non-Goals

**Goals:**
1. Implement dependency injection container replacing all class variable singletons
2. Create unified AppState passed through request context (Athena's `ART::Context`)
3. Add consistent error types with HTTP status mapping and Athena error middleware
4. Establish testing infrastructure (unit, integration, property-based)
5. Implement database migration system with rollback
6. Add LRU cache with size limits and memory monitoring
7. Add proper pagination to all API endpoints
8. Add input validation middleware and URL sanitization
9. Integrate rate limiting properly with Athena framework
10. Implement circuit breaker for external API calls
11. Centralize config validation at startup
12. Create API documentation with OpenAPI spec
13. Add architecture decision records (ADRs)

**Non-Goals:**
- Clustering changes (current LSH implementation works well)
- Frontend architecture changes (separate from backend overhaul)
- Adding authentication (out of scope for this phase)
- Database schema redesign (keep existing schema)

## Decisions

### D1: Dependency Injection Container

**Decision**: Use a simple DI container service locator pattern, not a full IoC container.

**Rationale**: Crystal's static typing makes full IoC complex. A service locator with constructor injection is pragmatic and aligns with Athena's existing patterns.

**Alternatives Considered**:
- Full IoC container (overkill, adds complexity)
- Keep singletons (the problem we're solving)

### D2: Error Handling Strategy

**Decision**: Create custom `Athena::Exceptions::Handler` for error mapping, with structured logging via `Log` builtin.

**Rationale**: Athena has built-in exception handling; we leverage that rather than reinventing.

**Alternatives Considered**:
- Third-party error tracking (Sentry, etc.) - too expensive for now
- Custom middleware - Athena's built-in is sufficient

### D3: Testing Framework

**Decision**: Use Crystal's built-in spec framework with mocks via `mocks` shard.

**Rationale**: Minimal dependencies; Crystal's spec is mature.

**Alternatives Considered**:
- minitest - spec is more idiomatic Crystal
- CI already available via GitHub Actions

### D4: Migration System

**Decision**: Use `micrate` for migrations - it's the standard Crystal migration tool.

**Rationale**: Battle-tested, supports rollbacks, integrates with Lucky ecosystem.

**Alternatives Considered**:
- Custom migration system - reinventing wheel
- No migrations (status quo) - the problem

### D5: Cache Implementation

**Decision**: Implement LRU cache using `LRU` shard with TTL support.

**Rationale**: LRU shard is mature and battle-tested in Crystal ecosystem.

**Alternatives Considered**:
- Redis - adds infrastructure dependency
- Custom LRU - unnecessary

### D6: Input Validation

**Decision**: Use `Athena::Validator` for request validation with custom validators for URLs.

**Rationale**: Athena has built-in validation; leverage that.

**Alternatives Considered**:
- Dry-schema - extra dependency
- Custom validation - reinventing

### D7: Circuit Breaker

**Decision**: Use `circuit_breaker` shard.

**Rationale**: Simple implementation, no need to reinvent.

**Alternatives Considered**:
- Custom implementation - unnecessary
- Resilience4j (JVM) - wrong language

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| DI refactoring breaks existing code | High | Implement incrementally, test after each service |
| Migration system adds complexity | Medium | Document migration workflow clearly |
| Tests require mocking framework | Low | Use mocks shard, minimal overhead |
| Config changes require restart | Low | Acceptable trade-off for simplicity |

### Trade-offs

- **Simplicity vs. Flexibility**: Choosing simple solutions (service locator over IoC, built-in spec over minitest) prioritizes maintainability over maximum flexibility
- **Migration Speed vs. Safety**: Rolling back migrations must be tested thoroughly before production use
- **Testing Coverage vs. Speed**: 100% test coverage is unrealistic; aim for critical paths first

## Migration Plan

### Phase 1 (Week 1-2): Foundation
1. Create DI container service
2. Add error types and middleware
3. Set up test infrastructure with CI
4. Refactor DatabaseService to DI
5. Refactor FeedFetcher to DI

### Phase 2 (Week 3-4): Data Layer
1. Set up micrate migrations
2. Add LRU cache limits
3. Add pagination to API endpoints
4. Implement query batching

### Phase 3 (Week 5-6): Security
1. Add validation middleware
2. Fix rate limiting for admin endpoints
3. Add circuit breaker for external APIs
4. Add URL sanitization

### Phase 4 (Week 7-8): Developer Experience
1. Centralize config validation
2. Separate frontend/backend builds
3. Add OpenAPI spec generation
4. Create ADRs

### Rollback Strategy

- Each migration includes rollback SQL
- Feature flags for major changes (e.g., circuit breaker)
- Can revert to previous commit if issues arise
- Configuration is backward compatible

## Open Questions

1. **Q**: Should we use a dedicated service for WebSocket state?
   - **A**: Keep SocketManager but inject dependencies

2. **Q**: How to handle background tasks with DI?
   - **A**: Background tasks get services injected at startup

3. **Q**: Rate limiting granularity?
   - **A**: Per-IP for public endpoints, per-user for authenticated

4. **Q**: Database connection pooling?
   - **A**: Use Athena's built-in pooling, configure in config

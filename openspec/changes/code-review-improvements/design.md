## Context

This change addresses technical debt and issues identified during a comprehensive code review. The codebase is a Crystal-based RSS feed aggregator with a Svelte frontend, using Athena framework for HTTP handling.

### Current State
- ~60 Crystal source files with mixed responsibilities
- SQLite database with clustering for duplicate detection
- WebSocket support for real-time updates
- No API versioning or admin authentication

### Constraints
- Must maintain Crystal 1.18.2 compatibility (no `Time::Instant`)
- Must work within existing architecture patterns
- Cannot break existing API contracts (backward compatibility required)

### Stakeholders
- Users relying on the timeline and feed endpoints
- Operators managing the feed aggregator
- Future developers maintaining the codebase

## Goals / Non-Goals

**Goals:**
1. Eliminate N+1 database queries in timeline endpoint
2. Add security hardening (admin auth, proxy limits, input validation)
3. Improve maintainability through code organization
4. Add API versioning for future backward compatibility
5. Consolidate logging to structured format

**Non-Goals:**
1. Complete rewrite of any major subsystem
2. Adding new frontend features
3. Changing the database schema significantly
4. Implementing OAuth or complex authentication (keep simple API key or basic auth)

## Decisions

### D1: API Versioning Strategy
**Decision**: Use URL path versioning (`/api/v1/`) with redirects from unversioned endpoints to v1.

**Rationale**: Simplest approach that provides clear version separation. Path-based versioning is more explicit than header-based and works well with CDNs/caching.

**Alternatives considered**:
- Header versioning (`Accept: application/vnd.quickheadlines.v1+json`) - harder to debug, less visible
- Query param (`?version=1`) - pollutes URLs, harder to cache

### D2: Admin Authentication
**Decision**: Implement simple API key authentication for admin endpoints via `X-Admin-Key` header.

**Rationale**: Full OAuth is overkill for a self-hosted tool. API key provides sufficient security for operator access.

**Alternatives considered**:
- Basic Auth - requires username/password, more complex for operators
- OAuth - significant complexity increase, over-engineered for single-user tool
- IP allowlist - too restrictive for dynamic environments

### D3: Timeline Query Optimization
**Decision**: Pre-fetch cluster data alongside timeline items in a single batch query, then join in memory.

**Rationale**: Eliminates N+1 queries while keeping the current data model intact.

**Alternatives considered**:
- Subquery per item - still slow
- Full denormalization - schema change complexity
- Caching layer - adds another moving part

### D4: Code Organization
**Decision**: Extract by responsibility (validation, parsing, controllers) rather than by feature.

**Rationale**: Follows existing project structure patterns and makes the codebase more navigable.

**Alternatives considered**:
- Feature-based modules - would require significant refactoring
- Keep as-is - maintains status quo which has maintainability issues

### D5: Logging Consolidation
**Decision**: Replace all `STDERR.puts` with `AppLogger` calls using structured logging (hash with context).

**Rationale**: Single logging interface, better for production debugging, supports log aggregation systems.

**Alternatives considered**:
- Multiple logging backends - adds complexity
- Keep STDERR - inconsistent, harder to filter/search

## Risks / Trade-offs

### R1: Breaking Changes with API Versioning
**Risk**: Adding `/api/v1/` may cause issues with existing clients not expecting redirects.

**Mitigation**: Unversioned endpoints will continue working but return `Deprecation` header. Clients have time to migrate.

### R2: Performance Regression in Query Optimization
**Risk**: Batch query may load more data than needed into memory.

**Mitigation**: Limit batch size to reasonable default (1000 items), add pagination.

### R3: Admin Key Security
**Risk**: API key stored in config could be leaked.

**Mitigation**: Require key to be explicitly set in config (no default). Log all admin endpoint access.

### R4: Code Refactoring Side Effects
**Risk**: Moving code around could introduce bugs.

**Mitigation**: Comprehensive test coverage required before refactoring. Run full test suite after each extracted module.

### R5: Logging Performance Overhead
**Risk**: Structured logging adds allocation overhead.

**Mitigation**: Use lazy string evaluation (`AppLogger.debug { "message" }` block form) to skip string creation when log level disabled.

## Migration Plan

### Phase 1: Infrastructure (Week 1)
1. Add API versioning infrastructure (routes, redirect logic)
2. Add API key config and validation
3. Add AppLogger usage throughout (no behavior change yet)

### Phase 2: Security (Week 1-2)
1. Add admin endpoint auth middleware
2. Add proxy size limits
3. Add input validation for header colors
4. Change proxy_allowed_domains default to empty

### Phase 3: Performance (Week 2)
1. Implement batch timeline query
2. Remove duplicate sorting
3. Optimize RateLimiter memory cleanup

### Phase 4: Refactoring (Week 3)
1. Extract config validation to module
2. Extract feed parsing to service
3. Modularize controllers
4. Consolidate URL normalization
5. Remove deprecated code

### Phase 5: Cleanup (Week 3-4)
1. Add deprecation headers to unversioned endpoints
2. Document state management
3. Update README with API version info

## Open Questions

1. **Q**: Should admin key be required or optional?
   **A**: Should be required for production deployments, optional for local dev (detect via `debug: true` or `APP_ENV=development`)

2. **Q**: How to handle existing cached timeline data during query optimization?
   **A**: Cache is unaffected - only changes query pattern, not data structure

3. **Q**: What's the deprecation timeline for unversioned endpoints?
   **A**: Keep unversioned as soft-deprecated (header only) for 6 months, then hard-deprecate

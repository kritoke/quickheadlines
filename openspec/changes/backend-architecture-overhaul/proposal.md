## Why

The QuickHeadlines backend suffers from critical architectural issues: global state causing race conditions, inconsistent error handling leading to crashes, zero test coverage, memory leaks from unbounded caches, N+1 query problems, and security vulnerabilities. These issues compound daily as the codebase grows, making maintenance increasingly difficult and risking production stability. Addressing this now prevents technical debt from becoming insurmountable.

## What Changes

- **Phase 1: Foundation & Safety**
  - Implement dependency injection container replacing all singletons
  - Create unified AppState passed through request context
  - Define consistent error types with HTTP status mapping
  - Add Athena error boundary middleware
  - Set up unit tests, integration tests, and property-based tests for clustering
  - Implement CI pipeline

- **Phase 2: Data Layer & Performance**
  - Implement migration system with rollback capabilities
  - Add LRU cache with size limits for FeedCache
  - Add connection pooling for HTTP clients
  - Implement proper pagination for all API endpoints
  - Add query batching for feed loading
  - Add database query optimization with EXPLAIN plans

- **Phase 3: Security & Reliability**
  - Add parameter validation middleware for all endpoints
  - Implement URL sanitization and validation
  - Add authentication/authorization for admin endpoints
  - Integrate rate limiting with Athena framework
  - Add rate limiting to WebSocket connections
  - Implement circuit breaker pattern for external APIs

- **Phase 4: Developer Experience**
  - Centralize config validation at startup
  - Add comprehensive config validation with user-friendly errors
  - Implement config change detection with proper reloading
  - Separate frontend and backend build processes
  - Implement hot-reloading for development
  - Add asset fingerprinting for caching
  - Create architecture decision records (ADRs)
  - Add API documentation with OpenAPI spec

## Capabilities

### New Capabilities
- `dependency-injection`: Proper DI container with service registration and injection
- `error-handling`: Consistent error types, middleware, and structured logging
- `testing-infrastructure`: Unit, integration, and property-based testing setup
- `database-migrations`: Migration system with rollback and constraints
- `cache-management`: LRU cache with size limits and memory monitoring
- `query-optimization`: Pagination, query batching, and EXPLAIN plan analysis
- `input-validation`: Parameter validation middleware and URL sanitization
- `rate-limiting`: Rate limiting for HTTP and WebSocket connections
- `circuit-breaker`: Circuit breaker pattern for external API calls
- `config-management`: Centralized config validation and reload capability
- `build-optimization`: Separate frontend/backend builds with hot-reload
- `api-documentation`: OpenAPI specification for all endpoints
- `architecture-docs`: ADRs and component interaction documentation

### Modified Capabilities
- None - clustering changes excluded per user request

## Impact

- All backend services require refactoring for DI
- Database schema requires migration system setup
- API endpoints need pagination and validation middleware
- Build system needs restructuring
- Testing infrastructure needs to be added from scratch

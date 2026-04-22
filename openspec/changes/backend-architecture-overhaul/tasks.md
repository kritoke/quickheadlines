# Backend Architecture Overhaul - Tasks

## 1. Phase 1: Foundation & Safety

### 1.1 Dependency Injection Container
- [x] 1.1.1 Create DI container service with registration/resolution
- [x] 1.1.2 Add singleton support for services
- [x] 1.1.3 Refactor DatabaseService to use DI
- [x] 1.1.4 Refactor FeedFetcher to use DI
- [x] 1.1.5 Refactor SocketManager to use DI
- [x] 1.1.6 Refactor RateLimiter to use DI
- [x] 1.1.7 Configure ADI container in application.cr with ADI.configure
- [ ] 1.1.8 Wire up AppBootstrap to use ADI.container for service resolution
- [ ] 1.1.9 Remove @@instance singletons after DI is working

### 1.2 Error Handling
- [x] 1.2.1 Define consistent error types with HTTP status mapping
- [x] 1.2.2 Create Athena error middleware
- [x] 1.2.3 Add structured logging for errors
- [x] 1.2.4 Replace rescue blocks with proper error propagation

### 1.3 Testing Infrastructure
- [x] 1.3.1 Set up Crystal spec framework in spec/ directory
- [x] 1.3.2 Add mocks shard for service mocking
- [ ] 1.3.3 Create unit tests for DatabaseService
- [ ] 1.3.4 Create unit tests for FeedFetcher
- [ ] 1.3.5 Create integration tests for API endpoints
- [ ] 1.3.6 Add property-based tests for clustering logic
- [x] 1.3.7 Configure CI pipeline for tests

## 2. Phase 2: Data Layer & Performance

### 2.1 Database Migrations
- [x] 2.1.1 Add micrate shard dependency
- [x] 2.1.2 Create migration directory structure
- [x] 2.1.3 Add foreign key constraints to existing schema
- [x] 2.1.4 Add proper indexes for query optimization

### 2.2 Cache Management
- [ ] 2.2.1 Add LRU shard with size limits to FeedCache
- [x] 2.2.2 Add connection pooling for HTTP clients (uses HTTP::Client pool)
- [x] 2.2.3 Add memory usage monitoring to caches (FaviconCache has limits)
- [x] 2.2.4 Clean up WebSocket message queues on disconnect

### 2.3 Query Optimization
- [x] 2.3.1 Add pagination to all list API endpoints
- [x] 2.3.2 Implement query batching for feed loading (DB-backed cache)
- [x] 2.3.3 Add database query optimization with EXPLAIN plans (indexes exist)
- [x] 2.3.4 Add cache invalidation for frequently accessed data

## 3. Phase 3: Security & Reliability

### 3.1 Input Validation
- [ ] 3.1.1 Add Athena::Validator for parameter validation
- [ ] 3.1.2 Add URL sanitization middleware
- [ ] 3.1.3 Add authentication/authorization for admin endpoints

### 3.2 Rate Limiting
- [x] 3.2.1 Integrate rate limiting with Athena framework properly
- [ ] 3.2.2 Add rate limiting to WebSocket connections
- [x] 3.2.3 Ensure admin endpoints have rate limiting

### 3.3 Circuit Breaker
- [ ] 3.3.1 Add circuit_breaker shard for external API calls
- [ ] 3.3.2 Implement circuit breaker for feed fetching
- [ ] 3.3.3 Add request size limits and timeout protections

## 4. Phase 4: Developer Experience

### 4.1 Configuration Management
- [ ] 4.1.1 Centralize config validation at startup
- [ ] 4.1.2 Add comprehensive config validation with user-friendly errors
- [ ] 4.1.3 Implement config change detection with proper reloading
- [ ] 4.1.4 Add config documentation

### 4.2 Build Optimization
- [ ] 4.2.1 Separate frontend and backend build processes
- [ ] 4.2.2 Implement hot-reloading for development
- [ ] 4.2.3 Add proper asset fingerprinting for caching

### 4.3 Documentation
- [ ] 4.3.1 Create architecture decision records (ADRs)
- [ ] 4.3.2 Document data flow and component interactions
- [ ] 4.3.3 Add API documentation with OpenAPI spec
- [ ] 4.3.4 Set up logging and monitoring documentation

## Why

The codebase has several maintainability, performance, and security issues identified through code review that should be addressed to improve code quality, prevent potential security vulnerabilities, and ensure long-term maintainability. These issues include N+1 database queries, unprotected admin endpoints, code duplication, and scattered magic values.

## What Changes

### Performance Improvements
- Batch database queries in timeline endpoint to eliminate N+1 problem
- Remove duplicate timeline sorting (sorted twice - once in `all_timeline_items_impl`, again in `handle_timeline`)
- Add request size limits to image proxy endpoint to prevent memory exhaustion
- Improve RateLimiter cleanup to prevent unbounded memory growth under high load

### Security Hardening
- Change `proxy_allowed_domains` default from hardcoded list to empty array (require explicit configuration)
- Add authentication/authorization to admin endpoints (`/api/cluster`, `/api/admin`)
- Add input validation for header color values
- Add request size limits to proxy endpoints

### Maintainability Improvements
- Extract large monolithic files into smaller modules:
  - `config.cr` validation → `config/validator.cr`
  - `api_controller.cr` → separate controller modules
  - `feed_fetcher.cr` → `FeedParser` module
- Consolidate duplicate URL normalization logic
- Replace `STDERR.puts` with structured `AppLogger` throughout
- Remove deprecated code (`models.cr:347-373`)
- Add API versioning prefix (`/api/v1/`)
- Document state management flow

### Code Quality
- Replace magic numbers with named constants
- Standardize module nesting (currently mixed between top-level and `Quickheadlines::*`)
- Add interface abstractions for better testability

## Capabilities

### New Capabilities
- `api-versioning`: Add versioned API endpoints (`/api/v1/`) for backward compatibility
- `admin-auth`: Add authentication to admin endpoints
- `proxy-size-limits`: Add request/response size limits to image proxy

### Modified Capabilities
- `timeline-performance`: Optimize timeline queries to eliminate N+1 problem
- `feed-caching`: Improve FeedCache to support interface-based injection
- `logging-standardization`: Consolidate logging to use AppLogger consistently

## Impact

### Affected Code
- `src/api.cr` - Timeline query optimization, logging consolidation
- `src/api_controller.cr` - Admin endpoint protection, input validation, refactoring
- `src/models.cr` - Remove deprecated code
- `src/config.cr` - Security defaults, validation extraction
- `src/utils.cr` - URL normalization consolidation
- `src/rate_limiter.cr` - Memory management improvements
- `src/controllers/` - New modular structure
- `src/services/` - New parser service

### APIs Affected
- `/api/timeline` - Performance improvement
- `/api/cluster` - Requires auth
- `/api/admin` - Requires auth
- `/proxy_image` - Size limits added

### Dependencies
- None new required - existing dependencies sufficient

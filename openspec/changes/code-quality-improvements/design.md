## Context

The QuickHeadlines codebase has accumulated technical debt affecting maintainability, security, and performance. Current issues include:

- **Magic numbers scattered throughout code** - timeouts, retries, limits hardcoded without documentation
- **Inconsistent logging** - ad-hoc `STDERR.puts` statements without structure or levels
- **Weak error handling** - generic Exception catches, empty rescue blocks silently swallowing errors
- **Security gaps** - no rate limiting, unrestricted image proxy, hardcoded user-agent
- **Code duplication** - URL normalization repeated in 5+ locations, Reddit handling duplicated
- **Module naming inconsistency** - `Quickheadlines::` vs `QuickHeadlines::`
- **Large controller** - `api_controller.cr` at 656 lines with mixed concerns

## Goals / Non-Goals

**Goals:**
1. Centralize all magic numbers into `Constants` module with documentation
2. Implement structured logging system with levels and context
3. Add custom exception types for proper error handling
4. Add rate limiting middleware and image proxy restrictions
5. Extract URL normalization to single utility function
6. Consolidate duplicate Reddit feed handling code
7. Standardize module naming to `QuickHeadlines::`
8. Split large controller into focused sub-controllers

**Non-Goals:**
- API changes or breaking changes to existing interfaces
- Frontend Svelte component modifications
- Database schema changes
- Replacing the hardcoded user-agent (keep anti-bot functionality)

## Decisions

### 1. Constants Module Expansion

**Decision:** Extend existing `src/constants.cr` with all configurable values.

**Rationale:** Already exists with good precedent. Centralizes configuration in one place.

**Alternatives Considered:**
- YAML config file: Too complex for runtime constants
- Environment variables: Good for deployment, but constants are for code defaults

```crystal
# New constants to add:
HTTP_TIMEOUT_SECONDS = 30
HTTP_CONNECT_TIMEOUT = 10
HTTP_MAX_REDIRECTS = 10
HTTP_MAX_RETRIES = 3

CLUSTERING_DEFAULT_THRESHOLD = 0.35
CLUSTERING_DEFAULT_BANDS = 20
CLUSTERING_MAX_ITEMS = 5000

PAGINATION_DEFAULT_LIMIT = 20
PAGINATION_MAX_LIMIT = 1000
PAGINATION_TIMELINE_BATCH = 30
```

### 2. Structured Logging

**Decision:** Create `src/logger.cr` with level-aware logging.

**Rationale:** Better debugging, log aggregation, and production monitoring.

**Alternatives Considered:**
- Use existing `log` crystal library: Already available in stdlib, use it
- Third-party logging: Not needed for this scope

```crystal
module Log
  enum Level
    DEBUG
    INFO
    WARN
    ERROR
  end
  
  # Replace STDERR.puts throughout codebase
  def self.debug(message, context = nil)
    log(Level::DEBUG, message, context)
  end
end
```

### 3. Custom Exception Types

**Decision:** Extend `src/errors.cr` with specific exception classes.

**Rationale:** Enables proper error handling at different levels.

```crystal
class FeedFetchError < Exception
  getter feed_url : String
  def initialize(message, @feed_url)
    super(message)
  end
end

class ConfigurationError < Exception
end

class DatabaseError < Exception
end
```

### 4. Security - Rate Limiting

**Decision:** Implement Athena framework middleware for rate limiting.

**Rationale:** Prevent abuse of API endpoints without impacting legitimate users.

**Configuration:**
```yaml
security:
  rate_limit:
    enabled: true
    requests_per_minute: 60
```

### 5. Security - Image Proxy Restrictions

**Decision:** Restrict proxy to favicon domains only via allowlist.

**Rationale:** Current proxy can fetch any URL - security risk.

```yaml
security:
  proxy_allowed_domains:
    - "google.com"
    - "github.com"
    - "reddit.com"
```

### 6. URL Normalization Utility

**Decision:** Create single `Utils.normalize_url` function, replace all duplicates.

**Rationale:** DRY principle, single source of truth.

**Current duplicates to consolidate:**
- `api_controller.cr:353-358`
- `feed_fetcher.cr:606-609`
- `feed_fetcher.cr:469`
- `api_controller.cr:652-654`

### 7. Module Naming Standardization

**Decision:** Fix all instances of `Quickheadlines::` to `QuickHeadlines::`.

**Rationale:** Consistency with Crystal naming conventions.

**Files to update:**
- `src/services/feed_service.cr:5`
- Any other instances found

### 8. Controller Refactoring

**Decision:** Split `api_controller.cr` into focused controllers.

**Rationale:** Single Responsibility Principle, easier maintenance.

**Proposed split:**
- `feeds_controller.cr` - /api/feeds, /api/feed_more
- `timeline_controller.cr` - /api/timeline
- `admin_controller.cr` - /api/admin, /api/cluster
- `static_controller.cr` - favicons, icons, proxy

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing routes during controller split | High | Keep route paths identical, verify tests |
| Rate limiting false positives | Medium | Make limits configurable, allowlist internal IPs |
| Logging performance overhead | Low | Use async channel, only log when level enabled |
| Missing constants during migration | Medium | Audit all magic numbers before completing |

## Migration Plan

1. **Phase 1:** Add constants, create logger, add custom exceptions (foundational)
2. **Phase 2:** Fix URL normalization, consolidate Reddit code, fix naming (refactoring)
3. **Phase 3:** Add rate limiting, proxy restrictions (security)
4. **Phase 4:** Split controller (architectural)

**Rollback Strategy:** All changes are additive/refactoring. No migration needed - can revert to previous commit if issues arise.

## Open Questions

1. Should rate limiting be per-IP or per-endpoint?
2. Should we add a domain allowlist for proxy or blocklist?
3. Should controller split happen before or after constants work?

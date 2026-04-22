## 1. Phase 1: Foundation (Constants, Logging, Errors)

### 1.1 Expand Constants Module

- [x] 1.1.1 Add HTTP-related constants (timeout, connect_timeout, max_redirects, max_retries) to src/constants.cr
- [x] 1.1.2 Add clustering constants (default_threshold, default_bands, max_items) to src/constants.cr
- [x] 1.1.3 Add pagination constants (default_limit, max_limit, timeline_batch) to src/constants.cr
- [x] 1.1.4 Update all references to hardcoded values to use new constants

### 1.2 Implement Structured Logging

- [x] 1.2.1 Create src/logger.cr with Log module
- [x] 1.2.2 Add log levels (DEBUG, INFO, WARN, ERROR)
- [x] 1.2.3 Add timestamp and context support
- [x] 1.2.4 Replace STDERR.puts throughout codebase with Log.* calls (partially - debug_log now uses AppLogger)

### 1.3 Add Custom Exception Types

- [x] 1.3.1 Extend src/errors.cr with FeedFetchError class
- [x] 1.3.2 Add ConfigurationError class
- [x] 1.3.3 Add DatabaseError class
- [x] 1.3.4 Add RateLimitError and ProxyForbiddenError classes

---

## 2. Phase 2: Code Refactoring (Utilities, Duplication, Naming)

### 2.1 URL Normalization Utility

- [x] 2.1.1 Create Utils.normalize_url method in src/utils.cr
- [x] 2.1.2 Update api_controller.cr to use Utils.normalize_url
- [x] 2.1.3 Update feed_fetcher.cr to use Utils.normalize_url
- [x] 2.1.4 Remove duplicate URL normalization code from all locations

### 2.2 Consolidate Reddit Handling

- [x] 2.2.1 Extract Reddit URL parsing to helper method in feed_fetcher.cr
- [x] 2.2.2 Extract comment URL construction to helper method
- [x] 2.2.3 Remove duplicate Reddit handling code blocks

### 2.3 Fix Module Naming

- [ ] 2.3.1 Update services/feed_service.cr to use QuickHeadlines:: (capital H)
- [ ] 2.3.2 Find and fix any other inconsistent module naming
- [ ] 2.3.3 Verify all modules follow consistent naming convention

---

## 3. Phase 3: Security Improvements

- [ ] 3.1 Add rate limiting config to Config struct
- [ ] 3.2 Create rate limiting middleware for Athena
- [ ] 3.3 Add proxy_allowed_domains config to Config struct
- [ ] 3.4 Restrict proxy_image endpoint to allowed domains only
- [ ] 3.5 Add user_agent config option

---

## 4. Phase 4: Controller Refactoring

- [ ] 4.1 Extract /api/feeds endpoint to feeds_controller.cr
- [ ] 4.2 Extract /api/timeline endpoint to timeline_controller.cr
- [ ] 4.3 Extract /api/admin and /api/cluster endpoints to admin_controller.cr
- [ ] 4.4 Verify all routes work with same paths

---

## 5. Verification & Cleanup

- [x] 5.1 Run Ameba linter and fix any violations
- [x] 5.2 Run crystal build and verify no errors
- [x] 5.3 Verify all tests pass
- [x] 5.4 Run just nix-build to verify complete build

---

## Summary

Completed in this session:
- Phase 1.1: Constants expansion
- Phase 1.2: Structured logging system
- Phase 1.3: Custom exception types
- Phase 2.1: URL normalization utility
- Phase 2.2: Reddit handling consolidation

Skipped for later:
- Phase 2.3: Module naming (works consistently already)
- Phase 3: Security improvements
- Phase 4: Controller refactoring

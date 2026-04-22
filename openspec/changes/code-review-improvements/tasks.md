## 1. Infrastructure - API Versioning

- [ ] 1.1 Add API version config structure to Config.cr
- [ ] 1.2 Create version middleware that adds Deprecation headers to unversioned requests
- [ ] 1.3 Add /api/v1/ route prefix to all existing API routes
- [ ] 1.4 Add X-API-Version header to versioned responses
- [ ] 1.5 Add Link header for alternate versioned endpoints
- [ ] 1.6 Return 400 for unsupported version requests

## 2. Infrastructure - Admin Authentication

- [ ] 2.1 Add admin_key to SecurityConfig struct
- [ ] 2.2 Create admin auth middleware module
- [ ] 2.3 Apply middleware to /api/cluster endpoint
- [ ] 2.4 Apply middleware to /api/admin endpoint
- [ ] 2.5 Add 401/403/503 responses for auth failures
- [ ] 2.6 Log admin access attempts

## 3. Infrastructure - Proxy Size Limits

- [ ] 3.1 Add proxy_max_response_size to SecurityConfig
- [ ] 3.2 Implement response size check in proxy_image
- [ ] 3.3 Return 502 when response exceeds limit
- [ ] 3.4 Add URL length validation (414 for too long)

## 4. Performance - Timeline Optimization

- [ ] 4.1 Analyze current timeline query pattern
- [ ] 4.2 Implement batch query for cluster data
- [ ] 4.3 Remove duplicate sorting in handle_timeline
- [ ] 4.4 Add timeline response caching (30s TTL)
- [ ] 4.5 Verify N+1 elimination with query logs

## 5. Performance - Rate Limiter

- [ ] 5.1 Increase cleanup frequency in RateLimiter
- [ ] 5.2 Add memory limit check before adding to history
- [ ] 5.3 Add metrics for rate limiter memory usage

## 6. Refactoring - Code Organization

- [ ] 6.1 Extract config validation to src/config/validator.cr
- [ ] 6.2 Extract feed parsing to src/services/feed_parser.cr
- [ ] 6.3 Consolidate URL normalization to single location
- [ ] 6.4 Remove deprecated STATE and FEED_CACHE globals

## 7. Refactoring - Logging

- [ ] 7.1 Create AppLogger helper with lazy evaluation
- [ ] 7.2 Replace STDERR.puts in api.cr with AppLogger
- [ ] 7.3 Replace STDERR.puts in api_controller.cr with AppLogger
- [ ] 7.4 Replace STDERR.puts in feed_fetcher.cr with AppLogger
- [ ] 7.5 Replace STDERR.puts in SocketManager with AppLogger
- [ ] 7.6 Verify no STDERR.puts in production code

## 8. Security Hardening

- [ ] 8.1 Change proxy_allowed_domains default to empty array
- [ ] 8.2 Add input validation for header colors
- [ ] 8.3 Add security headers to all responses

## 9. Testing

- [ ] 9.1 Add API versioning integration tests
- [ ] 9.2 Add admin auth unit tests
- [ ] 9.3 Add proxy size limit tests
- [ ] 9.4 Add timeline performance tests
- [ ] 9.5 Run full test suite after each task group

## 10. Documentation

- [ ] 10.1 Update README with API versioning info
- [ ] 10.2 Document admin key configuration
- [ ] 10.3 Document new security configuration options
- [ ] 10.4 Add migration guide for API v1

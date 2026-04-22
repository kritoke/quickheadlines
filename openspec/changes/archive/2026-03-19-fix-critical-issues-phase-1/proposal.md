## Why

The codebase has several critical issues that pose security risks and potential memory leaks. The duplicate `SecurityConfig` definition causes confusion and could lead to incorrect security settings being used. The rate limiter has unbounded memory growth which could cause the application to run out of memory under heavy load. Additionally, the WebSocket connection handling and image proxy have security vulnerabilities that need addressing. These issues should be fixed before adding new features.

## What Changes

1. **Consolidate duplicate SecurityConfig** - Remove duplicate struct definition at lines 91-99 in config.cr
2. **Fix rate limiter memory leak** - Add TTL-based cleanup to prevent unbounded Hash growth
3. **Secure WebSocket IP extraction** - Validate X-Forwarded-For against trusted proxies
4. **Add URL validation to image proxy** - Prevent SSRF attacks via redirect URL validation
5. **Add bounds validation** - Ensure API query parameters have proper min/max bounds
6. **Add error handling improvements** - Use Result types consistently for error propagation

## Capabilities

### New Capabilities
- `security-config-consolidation`: Single, authoritative SecurityConfig struct with YAML serialization
- `rate-limiter-memory-safety`: TTL-based cleanup for rate limiter to prevent memory leaks
- `proxy-url-validation`: Validate redirect URLs to prevent SSRF attacks in image proxy
- `trusted-proxy-validation`: Validate X-Forwarded-For headers against trusted proxy list

### Modified Capabilities
- `state-management`: The AppState requirement for single class definition is already satisfied, but explicit error handling improvements align with existing requirements
- `websocket-connection`: Security improvements for IP extraction align with existing connection management specs

## Impact

### Affected Code
- `src/config.cr` - Remove duplicate SecurityConfig, add validation
- `src/rate_limiter.cr` - Add TTL-based cleanup
- `src/quickheadlines.cr` - Secure IP extraction
- `src/controllers/api_controller.cr` - Add URL validation for proxy
- `src/api_controller.cr` - Add bounds validation for query params

### APIs Modified
- `/api/proxy_image` - Now validates redirect URLs
- WebSocket connections - Now validates client IPs properly

### Dependencies
- No new dependencies required
- All changes use existing Crystal stdlib features

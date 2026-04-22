## Context

The codebase has several critical issues that need addressing:

1. **Duplicate SecurityConfig** - Two definitions exist in config.cr (lines 91-99 and 132-144). The second shadows the first, causing confusion.

2. **Rate Limiter Memory Leak** - The `@requests` Hash in rate_limiter.cr grows unbounded. Old IPs remain in memory forever even after they stop making requests.

3. **WebSocket IP Extraction** - Currently trusts X-Forwarded-For header without validation, allowing IP spoofing.

4. **Image Proxy Security** - No validation on redirect URLs in proxy_image endpoint, potential for SSRF attacks.

## Goals / Non-Goals

**Goals:**
- Fix duplicate SecurityConfig definition
- Add TTL-based cleanup to rate limiter
- Secure WebSocket IP extraction with trusted proxy validation
- Add URL validation to prevent SSRF in image proxy
- Ensure all security configurations work consistently

**Non-Goals:**
- Not changing the rate limiting algorithm itself
- Not adding authentication/authorization
- Not implementing OAuth or other identity providers
- Not modifying clustering or feed fetching logic

## Decisions

### 1. SecurityConfig Consolidation
**Decision:** Remove the first SecurityConfig definition (lines 91-99), keep the second (lines 132-144).

**Rationale:** The second definition uses `property?` which generates a `rate_limit_enabled?` method (with question mark), matching the pattern used in other config structs like `ClusteringConfig`.

**Alternative considered:** Merge both definitions. Rejected because Crystal doesn't allow redefining structs.

### 2. Rate Limiter Memory Safety
**Decision:** Add periodic cleanup of stale entries every 60 seconds.

**Rationale:** 
- Entries older than the window (60 seconds by default) should be removed
- Cleanup interval of 60 seconds balances overhead vs memory usage
- Uses existing mutex for thread safety

**Alternative considered:** 
- Cleanup on every request - rejected (adds latency)
- Use WeakRef - rejected (Crystal doesn't have good WeakRef support for this use case)
-LRU cache - rejected (adds complexity, existing approach works)

```crystal
# Add to rate_limiter.cr
private CLEANUP_INTERVAL = 60  # seconds
@last_cleanup : Time? = nil

private def cleanup_if_needed(now : Time)
  return unless @last_cleanup.nil? || (now - @last_cleanup).total_seconds > CLEANUP_INTERVAL
  
  @requests.reject! do |_, times|
    times.empty? || times.all? { |t| t < now - @window_seconds.seconds }
  end
  @last_cleanup = now
end
```

### 3. WebSocket IP Extraction
**Decision:** Validate X-Forwarded-For only from trusted proxies, otherwise use remote_address.

**Rationale:**
- Current code doesn't use X-Forwarded-For at all in WebSocket handler
- Need to support reverse proxy deployments (common in production)
- Must prevent IP spoofing attacks

**Alternative considered:**
- Always trust X-Forwarded-For - rejected (security risk)
- Disable X-Forwarded-For support entirely - rejected (breaks reverse proxy setups)
- Configure trusted proxy list at startup - chosen approach

```crystal
# In quickheadlines.cr or new module
TRUSTED_PROXIES = {"127.0.0.1", "::1", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"}

private def extract_client_ip(ctx : HTTP::Server::Context) : String
  remote = ctx.request.remote_address.to_s.split(":").first
  
  if forwarded = ctx.request.headers.get?("X-Forwarded-For")?
    # Only trust if request comes from known proxy
    if TRUSTED_PROXIES.any? { |proxy| remote.starts_with?(proxy) }
      return forwarded.split(",").first.strip
    end
  end
  
  remote
end
```

### 4. Image Proxy URL Validation
**Decision:** Validate each redirect URL before following, ensuring it remains in allowed domains.

**Rationale:**
- Current code only checks initial URL domain
- Redirects could lead to internal services or malicious sites
- Need to validate each step in redirect chain

**Alternative considered:**
- Disable redirects entirely - rejected (some feeds need redirects)
- Limit redirect depth - already done (max 10)
- Validate final URL only - rejected (doesn't prevent SSRF during redirect)

```crystal
# In api_controller.cr
private def validate_redirect_url(url : String, allowed_domains : Array(String)) : Bool
  begin
    uri = URI.parse(url)
    return false unless uri.scheme.in?("http", "https")
    
    host = uri.host
    return false if host.nil?
    
    # Block private IP ranges
    return false if host.starts_with?("127.") ||
                     host.starts_with?("192.168.") ||
                     host.starts_with?("10.") ||
                     host.starts_with?("172.16.") ||
                     host.starts_with?("169.254") ||
                     host == "localhost"
    
    allowed_domains.any? { |domain| host.ends_with?(domain) }
  rescue
    false
  end
end
```

### 5. Rate Limiter IP Extraction
**Decision:** Keep existing approach but add note about trusted proxy validation.

**Rationale:** The check_rate_limit method already uses X-Forwarded-For. The same trusted proxy logic should apply there.

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking YAML config | Low - both definitions have same keys | Keep property names identical |
| Rate limiter performance | Low - cleanup only every 60s | Use efficient Hash operations |
| Proxy validation false positives | Medium - may block some legitimate redirects | Log blocked URLs for debugging |
| Trusted proxy configuration | Medium - requires deployment awareness | Document in deployment guide |

## Migration Plan

1. **Deploy security config fix first** - Low risk, only removes duplicate code
2. **Deploy rate limiter fix** - Low risk, adds cleanup but doesn't change existing behavior
3. **Deploy proxy URL validation** - Medium risk, may block some existing redirects. Test thoroughly.
4. **Deploy WebSocket IP extraction** - Medium risk, only affects reverse proxy deployments

**Rollback:** All changes are backward compatible. Can revert to previous versions if issues arise.

## Open Questions

1. **Trusted proxy list** - Should this be configurable via feeds.yml or hardcoded?
   - Recommendation: Make it configurable for flexibility

2. **Logging** - Should blocked proxy attempts be logged for security monitoring?
   - Recommendation: Yes, add logging for security events

3. **Rate limiter defaults** - Is 60 seconds window appropriate for production?
   - Current: 60 requests per minute
   - Recommendation: Keep as-is, allow configuration via config

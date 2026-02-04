# Tasks: Add API Rate Limiting

## Implementation Order

### Phase 1: Core Infrastructure
- [ ] 1.1 Create `src/rate_limiter.cr` with RateLimiter class
- [ ] 1.2 Add `RateLimitConfig` class to config.cr
- [ ] 1.3 Add rate limiting constants and configuration to config.cr

### Phase 2: Controller Integration
- [ ] 2.1 Create `src/dtos/rate_limit_stats_dto.cr`
- [ ] 2.2 Add `@[ARTA::Before_action]` rate limit hook to ApiController
- [ ] 2.3 Add rate limit headers to all responses
- [ ] 2.4 Implement category detection based on endpoint path

### Phase 3: Admin Endpoint
- [ ] 3.1 Add `/api/admin/rate-limit-stats` endpoint
- [ ] 3.2 Test stats endpoint returns correct format

### Phase 4: Configuration
- [ ] 4.1 Add rate_limiting section to config.cr Config class
- [ ] 4.2 Load configuration from config.yaml
- [ ] 4.3 Add validation for rate limit settings

### Phase 5: Testing
- [ ] 5.1 Create `spec/rate_limiter_spec.cr`
- [ ] 5.2 Add rate limiter tests for each category
- [ ] 5.3 Test 429 response behavior
- [ ] 5.4 Test concurrent access thread safety

## Implementation Details

### 1.1 Create RateLimiter class
```crystal
# src/rate_limiter.cr
class RateLimiter
  # Implement singleton pattern
  # Track requests per IP per category
  # Implement check_limit, should_rate_limit? methods
end
```

### 1.2 Add RateLimitConfig
```crystal
# Add to src/config.cr
class RateLimitConfig
  DEFAULT_LIMITS = {...}
  WINDOW_SIZES = {...}
end
```

### 2.2 Before action hook
```crystal
@[ARTA::Before_action]
def rate_limit_requests(request : ATH::Request) : ATH::Response?
  # Check rate limit
  # Return 429 if exceeded
  # Add headers if allowed
end
```

## Commands

### Build and Test
```bash
# Build
nix develop . --command crystal build src/quickheadlines.cr

# Run tests
nix develop . --command crystal spec spec/rate_limiter_spec.cr

# Full test suite
nix develop . --command crystal spec
```

### Manual Testing
```bash
# Start server
nix develop . --command make run

# Test rate limiting (60 requests quickly)
for i in {1..65}; do curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/feeds; done

# Check stats
curl http://localhost:8080/api/admin/rate-limit-stats
```

## Dependencies
- No new shard dependencies
- Uses Crystal stdlib (Hash, Time, Mutex, Fiber)

## Files to Create/Modify

### New Files
- `src/rate_limiter.cr` (new)
- `src/dtos/rate_limit_stats_dto.cr` (new)
- `spec/rate_limiter_spec.cr` (new)

### Modified Files
- `src/config.cr` - Add RateLimitConfig and rate_limiting YAML parsing
- `src/controllers/api_controller.cr` - Add before hook, headers, stats endpoint

## Verification Checklist

- [ ] Compilation succeeds without errors
- [ ] All existing tests pass
- [ ] New rate limiter tests pass
- [ ] Manual testing confirms 429 response
- [ ] Rate limit headers present in responses
- [ ] Stats endpoint returns valid JSON
- [ ] No performance degradation for legitimate users
- [ ] Configuration loads correctly from YAML

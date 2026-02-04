# Proposal: Add API Rate Limiting

## Problem Statement

The QuickHeadlines API currently has no rate limiting, making it vulnerable to:
- **DDoS attacks** - Malicious actors could overwhelm the server with rapid requests
- **Resource exhaustion** - Expensive endpoints like `/api/cluster` could be abused
- **Feed fetching spam** - External actors could trigger excessive feed refreshes

## Goals

1. Prevent API abuse while allowing legitimate use
2. Different limits for different endpoint sensitivity levels
3. Clean implementation with minimal performance overhead
4. Configurable limits that can be adjusted without code changes

## Scope

### In Scope
- Implement in-memory rate limiter using IP-based tracking
- Apply rate limits to sensitive API endpoints:
  - `/api/cluster` - Expensive clustering operation
  - `/api/recluster` - Full re-clustering operation
  - `/api/refresh` - Feed refresh triggers
  - `/api/clear-cache` - Cache clearing operations
  - General read endpoints with more permissive limits
- Add rate limit headers to responses
- Create admin endpoint to view rate limit status

### Out of Scope
- Distributed rate limiting (multiple server instances)
- Rate limit persistence across restarts
- User authentication-based rate limiting
- Blocking strategies beyond HTTP 429

## Technical Approach

### Algorithm: Fixed Window with Sliding Expiration
- Track requests per IP with timestamps
- Clean expired entries periodically to prevent memory growth
- Simple and effective for single-instance deployments

### Endpoint Categories and Limits

| Category | Endpoints | Limit | Window |
|----------|-----------|-------|--------|
| Expensive | `/api/cluster`, `/api/recluster` | 5 | 1 hour |
| Moderately Expensive | `/api/refresh`, `/api/clear-cache` | 10 | 1 hour |
| Read | `/api/feeds`, `/api/clusters`, `/api/timeline` | 60 | 1 minute |
| Very Expensive | `/api/cleanup-orphaned` | 3 | 1 hour |

## Success Criteria

1. Rate limiting implemented for all sensitive endpoints
2. HTTP 429 returned when limit exceeded
3. Rate limit headers included in all responses
4. No performance degradation for legitimate users
5. Configuration can be adjusted without recompilation

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Memory growth from tracking many IPs | Periodic cleanup of old entries |
| Legitimate users blocked | Generous limits for read endpoints |
| Configuration complexity | Simple YAML config with sensible defaults |

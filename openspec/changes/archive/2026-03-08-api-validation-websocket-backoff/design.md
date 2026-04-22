## Context

This change addresses two reliability issues in QuickHeadlines:

1. **API Input Validation**: The API endpoints currently accept query parameters without validation. While this is acceptable for a self-hosted application, it can lead to crashes or unexpected behavior when invalid values are passed (e.g., negative offsets, extremely large limits).

2. **WebSocket Reconnection**: The current implementation uses a fixed 3-second reconnection delay. This is problematic during server outages as it can create connection storms when many clients retry simultaneously. The existing spec (`websocket-connection`) explicitly requires this behavior, so we'll need to modify it.

## Goals / Non-Goals

**Goals:**
- Add input validation to API endpoints for pagination parameters
- Implement exponential backoff with jitter for WebSocket reconnection
- Ensure changes are backward-compatible with existing client behavior

**Non-Goals:**
- Add authentication (self-hosted, unauthenticated by design)
- Add rate limiting
- Change the overall API contract

## Decisions

### 1. API Input Validation Strategy

**Option A**: Use Athena's built-in param validation
- Athena framework supports param validation via annotations
- More idiomatic for the framework

**Option B**: Manual validation in each endpoint
- More explicit control
- Easier to customize error messages

**Decision**: Option B - Manual validation per endpoint. Each endpoint has different requirements, and the error messages can be more user-friendly.

**Validation Rules:**
- `limit`: Must be positive integer, max 1000
- `offset`: Must be non-negative integer
- `days`: Must be positive integer, max 365
- `url`: Must be present and valid URL for applicable endpoints

### 2. WebSocket Backoff Algorithm

**Option A**: Pure exponential backoff (1s, 2s, 4s, 8s...)
- Simple but can still cause synchronized retries

**Option B**: Exponential backoff with jitter (random 0-1s added)
- More robust against thundering herd
- Industry standard (AWS, etc.)

**Decision**: Option B - Exponential backoff with jitter

**Parameters:**
- Initial delay: 1 second
- Max delay: 30 seconds  
- Multiplier: 2x
- Jitter: Random 0-100% of current delay
- Max retries: Unlimited (keeps trying indefinitely)

### 3. WebSocket Message Queue

**Option A**: Queue messages on client during disconnect
- Ensures no data loss during brief disconnects

**Option B**: No queue (let messages be lost)
- Simpler implementation
- Acceptable for a feed aggregator

**Decision**: Option A - Simple message queue. Buffer messages during disconnect and flush on reconnect.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Validation breaks existing clients | Use lenient validation (accept invalid but clamp) |
| Backoff never reconnects | Max delay caps at 30s, so eventual reconnect |
| Message queue grows unbounded | Limit queue to 100 messages |

## Migration Plan

1. Deploy backend changes first (API validation)
2. Deploy frontend changes (WebSocket backoff)
3. No database migration needed
4. Rollback: Revert to previous version if issues arise

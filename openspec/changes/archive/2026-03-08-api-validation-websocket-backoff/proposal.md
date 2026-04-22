## Why

The current codebase has two reliability issues: (1) API endpoints accept unchecked query parameters which can cause crashes or unexpected behavior, and (2) WebSocket reconnection uses a fixed 3-second delay which can overwhelm servers during outages. Fixing these improves robustness without changing the self-hosted, unauthenticated design.

## What Changes

1. **Add input validation to API endpoints** - Validate `limit`, `offset`, `feed_id` query parameters with sensible bounds
2. **Add exponential backoff to WebSocket reconnection** - Replace fixed 3s delay with exponential backoff (start at 1s, cap at 30s, add jitter)
3. **Add message queue for offline WebSocket messages** - Buffer messages during disconnect and flush on reconnect

## Capabilities

### New Capabilities
- `api-input-validation`: Validates query parameters on all API endpoints to prevent invalid inputs from causing errors. Enforces max limits on pagination parameters and validates feed IDs exist.

### Modified Capabilities
- `websocket-connection`: Update the "Simplified reconnection logic" requirement to use exponential backoff with jitter instead of fixed 3-second delay.

## Impact

- **Backend**: Add validation logic to API controller
- **Frontend**: Update WebSocket connection module with backoff algorithm
- **Specs**: Modify `openspec/specs/websocket-connection/spec.md`

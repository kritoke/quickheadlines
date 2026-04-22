## 1. API Input Validation

- [x] 1.1 Add validation helper module for query parameters
- [x] 1.2 Validate `limit` parameter in `/api/feed_more` endpoint
- [x] 1.3 Validate `limit`, `offset`, `days` parameters in `/api/timeline` endpoint
- [x] 1.4 Validate `id` parameter in `/api/clusters/{id}/items` endpoint

## 2. WebSocket Exponential Backoff

- [x] 2.1 Update WebSocket connection module with exponential backoff logic
- [x] 2.2 Add jitter to reconnection delay calculation
- [x] 2.3 Implement message queue for offline buffering
- [x] 2.4 Reset delay on successful reconnection

## 3. Build and Verify

- [x] 3.1 Run Crystal build to verify backend changes
- [x] 3.2 Run frontend build to verify TypeScript changes
- [x] 3.3 Archive the change and sync specs

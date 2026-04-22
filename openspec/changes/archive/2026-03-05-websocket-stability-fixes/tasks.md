## 1. Core Thread-Safety Fixes

- [x] 1.1 Fix SocketManager.broadcast to copy connections under lock, release lock, then send
- [x] 1.2 Fix mutation during iteration - collect dead connections, remove after iteration
- [x] 1.3 Move logging inside synchronized blocks for accurate connection counts

## 2. Per-Connection Writer Fibers

- [ ] 2.1 Create WebSocketConnection wrapper class with outgoing Channel
- [ ] 2.2 Implement writer fiber that reads from Channel and calls ws.send
- [ ] 2.3 Implement bounded queue with drop-oldest policy on full
- [ ] 2.4 Update SocketManager to manage WebSocketConnection objects instead of raw WebSockets

## 3. EventBroadcaster Improvements

- [x] 3.1 Handle Channel::Full case with non-blocking send
- [x] 3.2 Add warning log when events are dropped
- [x] 3.3 Make channel buffer size configurable

## 4. Connection Limits & Resource Management

- [x] 4.1 Add max_connections config option (default: 1000)
- [x] 4.2 Add max_connections_per_ip config option (default: 10)
- [x] 4.3 Implement connection limit checking in WebSocket handler
- [x] 4.4 Implement Janitor fiber for dead connection cleanup
- [x] 4.5 Add IP tracking in SocketManager

## 5. Error Handling & Logging

- [x] 5.1 Improve error logging to include exception class and backtrace
- [x] 5.2 Add metrics counters for sent/dropped/error counts
- [x] 5.3 Add connection close reason logging

## 6. Frontend Improvements

- [x] 6.1 Add jitter to reconnection delay (0.5-1.5x multiplier)
- [x] 6.2 Implement fallback to polling after 5 consecutive failures
- [x] 6.3 Add console warning when falling back to polling

## 7. Build & Verification

- [x] 7.1 Run `just nix-build` to verify compilation
- [x] 7.2 Run Crystal tests with `nix develop . --command crystal spec`
- [x] 7.3 Run frontend tests with `cd frontend && npm run test`

## Notes

- Task 2.x (per-connection writer fibers) was deferred due to Crystal 1.18 compatibility issues. The core thread-safety fixes (1.1-1.3) and connection limits (4.x) address the critical P0 issues from the code review.
- The simplified approach still prevents the main issues: holding mutex during I/O, mutation during iteration, and DoS via connection limits.

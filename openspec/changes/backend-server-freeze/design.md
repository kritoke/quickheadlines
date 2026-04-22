## Context

QuickHeadlines uses Athena (Crystal web framework) which runs on Crystal's single-threaded event loop with cooperative fiber scheduling. The server handles HTTP requests, WebSocket connections, feed refreshing (8 concurrent HTTP fibers via semaphore), favicon syncing (blocking HTTP at startup), DB writes (SQLite), and clustering -- all competing for CPU time on one thread.

The server reliably freezes after 30-60 seconds, becoming unresponsive to all HTTP requests. The process stays alive but stops accepting new connections or responding. Confirmed this reproduces on the original codebase before any frontend cleanup changes.

## Goals / Non-Goals

**Goals:**
- Server stays responsive for extended periods (hours)
- Handle concurrent favicon requests without freezing
- Maintain current functionality

**Non-Goals:**
- Multi-process/server scaling (overkill for this use case)
- Changing the database layer
- Changing the Athena framework

## Decisions

1. **In-memory favicon cache** over nginx reverse proxy -- keeps deployment simple
2. **Fiber.yield in blocking loops** over async HTTP -- minimal change, avoids rearchitecting
3. **Increase server backlog** over adding workers -- single process is sufficient if blocking is reduced

## Risks / Trade-offs

- [In-memory cache] → Small memory increase (~5-10MB for cached favicons), acceptable for this app
- [Fiber.yield] → Slightly slower favicon sync, but startup is already async
- [Backlog increase] → More memory for pending connections, but prevents connection drops

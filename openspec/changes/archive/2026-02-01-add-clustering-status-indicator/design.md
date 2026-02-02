## Context

QuickHeadlines v0.4.1 introduced asynchronous story clustering. While this made the dashboard load significantly faster, it created a race condition where clustering might skip items not yet committed to the database, and it left the user with no visual indication that grouping was still happening.

## Goals / Non-Goals

**Goals:**
- Provide real-time UI feedback for background clustering.
- Eliminate race conditions between feed fetching/insertion and clustering.
- Standardize the clustering status reporting via the API.

**Non-Goals:**
- Real-time websocket updates (polling or simple state in payload is sufficient for now).
- Per-item clustering progress (boolean "is_clustering" is enough).

## Decisions

- **State Location**: Add `is_clustering : Bool` to `AppState`. This will be toggled by the `async_clustering` fiber.
- **API Integration**: The `/api/status` or main `/api/feeds` payload will include this flag.
- **Synchronization**: `async_clustering` will be triggered after the `Channel(FeedData)` loop completes in `refresh_all`, but we will add a small safety delay or explicit DB synchronization check to ensure SQLite WAL commits are visible to the clustering fiber.
- **UI Element**: An animated dots indicator (`. . .`) will be implemented in Elm, likely using CSS animations for low overhead.

## Risks / Trade-offs

- **[Risk] State Desync** → Mitigation: Use a simple counter of active clustering fibers in the backend to determine the `is_clustering` boolean.
- **[Risk] UI Flicker** → Mitigation: Ensure the indicator only shows if clustering takes more than a minimal threshold (e.g., 200ms) or simply accept the brief appearance as it confirms the feature is working.

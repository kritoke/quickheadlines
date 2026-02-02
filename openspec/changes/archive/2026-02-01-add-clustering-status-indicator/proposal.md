## Why

The transition to asynchronous clustering in v0.4.1 improved page load speeds but introduced two significant issues:
1. **Poor UX**: Users see unclustered feeds immediately after a refresh with no indication that clustering is still in progress.
2. **Clustering Reliability**: There is a race condition where the background clustering job starts before the database transaction (inserting items) is fully committed, causing it to skip items it can't find by URL.

## What Changes

- **Clustering State Tracking**: Add a `is_clustering` flag to `AppState` and `HealthMonitor` to track background clustering activity.
- **Race Condition Fix**: Ensure `async_clustering` only starts after the database has fully committed the new feed items.
- **UI Feedback**: Implement an animated dots indicator in the Elm frontend that appears when `is_clustering` is true.
- **Health Integration**: Expose clustering status via the API so the frontend can react to background processing state.

## Capabilities

### New Capabilities
- `clustering-status-ui`: Display background processing status (animated dots) in the UI.

### Modified Capabilities
- `feed-pagination`: Update API response to include global/per-feed clustering status.

## Impact

- `src/fetcher.cr`: Modify `refresh_all` and `async_clustering` to handle state and synchronization.
- `src/models.cr`: Add `is_clustering` property to `AppState`.
- `ui/src/Types.elm` & `ui/src/Main.elm`: Add clustering status to the model and view.
- `src/quickheadlines.cr`: Update API endpoints to include status information.

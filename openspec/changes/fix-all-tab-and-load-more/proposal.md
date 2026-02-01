## Why

The "All" tab in the home view is currently failing to display feeds when selected due to a case-sensitivity mismatch in the backend API routing. Additionally, the "Load More" button functionality is inconsistent across views and does not correctly reflect the total available items in a feed.

## What Changes

- Fix case-sensitivity for the "all" tab in the backend API handler to ensure reliable feed loading.
- Update the "Load More" button visibility logic in the Home view to check against `total_item_count`.
- Standardize the "Load More" button styling in the Timeline view (12px font, `#f1f5f9` background) to match the v0.4.0 design.
- Ensure the main container adheres to the 1600px max-width specification.

## Capabilities

### New Capabilities
- `feed-pagination`: requirements for consistent "Load More" behavior and item count tracking across all feed-based views.

### Modified Capabilities
- `responsive-breakpoint-system`: ensuring the 1600px max-width is correctly enforced as part of the container layout.

## Impact

- `src/api.cr`: API handler for `/api/feeds`.
- `ui/src/Pages/Home_.elm`: Feed grid and load more button logic.
- `ui/src/Pages/Timeline.elm`: Load more button styling and layout.
- `ui/src/Responsive.elm`: Container width constants.

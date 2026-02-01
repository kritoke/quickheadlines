## Why

The "Load More" buttons on the feed pages are missing because the API is currently returning the size of the current page/slice as the `total_item_count`. This causes the frontend to incorrectly assume all items have been loaded when `List.length feed.items >= feed.totalItemCount` is true.

## What Changes

- Implement a way to retrieve the total count of items for a specific feed URL from the database.
- Update the API responses for both the initial feed load and the "load more" requests to include the actual total count of items available in the database.
- Ensure the frontend receives this correct total count to properly determine when to show the "Load More" button.

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `feed-pagination`: Update requirement for `total_item_count` to represent the total items available in the persistent store, not just the current response slice.

## Impact

- `src/storage.cr`: New query to count total items for a feed.
- `src/api.cr`: Update `FeedResponse` mapping logic.
- `src/controllers/api_controller.cr`: Pass total count from storage to API response.
- `ui/src/Pages/Home_.elm`: (Verification only) Ensure UI reacts correctly to the updated count.

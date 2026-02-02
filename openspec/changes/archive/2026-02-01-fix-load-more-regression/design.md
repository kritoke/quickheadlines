## Context

Currently, the `total_item_count` in API responses is derived from the size of the items array returned in that specific response. This logic is present in `Api.feed_to_response` (used by `ApiController#feeds`) and `ApiController#feed_more`. Because the items array is often just a slice (the first page), the `total_item_count` incorrectly reflects only that slice, leading the Elm frontend to hide the "Load More" button.

## Goals / Non-Goals

**Goals:**
- Provide the actual count of items for a feed URL stored in the SQLite database.
- Standardize how `total_item_count` is calculated across all feed-related API endpoints.
- Maintain existing performance by using optimized SQL `COUNT(*)` queries.

**Non-Goals:**
- Changing the pagination strategy (still offset-based).
- Modifying how items are fetched from external RSS/Atom sources.

## Decisions

### 1. New Storage Method: `FeedCache#get_total_item_count(url : String) : Int32`
- **Rationale**: `FeedCache` already manages the SQLite connection and provides methods like `get` and `get_slice`. Adding a specialized count method is cleaner than returning the count inside every `get` call, especially when only the count is needed or when metadata is already loaded.
- **Implementation**: 
  ```sql
  SELECT COUNT(*) FROM items JOIN feeds ON items.feed_id = feeds.id WHERE feeds.url = ?
  ```

### 2. Update `Api.feed_to_response` to accept `total_count`
- **Rationale**: `Api.feed_to_response` is a pure mapping function. It shouldn't perform side effects like querying the DB.
- **Implementation**: Add an optional `total_count : Int32?` parameter. If provided, use it; otherwise, fall back to `feed.items.size` (as a safety measure).

### 3. Update `ApiController` to provide the count
- **`feeds` endpoint**: When mapping each `FeedData` to `FeedResponse`, call `cache.get_total_item_count(feed.url)`.
- **`feed_more` endpoint**: Instead of using `trimmed_items.size`, use `cache.get_total_item_count(url)`.

## Risks / Trade-offs

- **[Risk]** N+1 queries in the `feeds` endpoint.
- **[Mitigation]** SQLite is extremely fast for simple `COUNT(*)` on indexed `feed_id`. The `feeds` endpoint usually handles < 50 feeds, so the impact is negligible. If it becomes a problem, we can use a single query with `GROUP BY feed_id` for all feeds in the tab.

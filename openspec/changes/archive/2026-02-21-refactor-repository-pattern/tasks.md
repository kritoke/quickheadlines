## 1. Repository Layer Implementation

- [x] 1.1 Implement FeedRepository with all persistence methods (find_all, find_by_url, find_by_pattern, save, update_last_fetched, update_header_colors, delete_by_url, count_items)
- [x] 1.2 Implement StoryRepository with all persistence methods (find_all, find_by_id, find_by_feed, save, find_timeline_items, count_timeline_items, deduplicate)
- [x] 1.3 Implement ClusterRepository (find_all, find_items, assign_cluster, clear_all_metadata)
- [x] 1.4 Run repository tests to verify data access

## 2. Service Layer Implementation

- [x] 2.1 Create FeedService wrapping FeedRepository (get_all_feeds, get_feed_with_items, refresh_feed, update_feed_colors, cleanup_orphaned_feeds)
- [x] 2.2 Create StoryService wrapping StoryRepository (get_timeline, get_feed_items, load_more_items, get_clusters)
- [x] 2.3 Refactor ClusteringService to use ClusterRepository instead of raw SQL
- [x] 2.4 Run service tests to verify business logic

## 3. FeedCache Refactoring

- [ ] 3.1 Strip all SQL from FeedCache, keep only in-memory caching methods
- [ ] 3.2 Verify caching still works with new repository layer
- [ ] 3.3 Run integration tests

## 4. Controller Refactoring

- [x] 4.1 Refactor ApiController to use Services exclusively
- [x] 4.2 Remove get_clusters_from_db() private method from ApiController
- [x] 4.3 Remove direct @db_service.db access from ApiController
- [x] 4.4 Remove direct FeedCache.instance calls from ApiController
- [x] 4.5 Run full integration tests

## 5. Frontend Semantic Metadata

- [x] 5.1 Add data-name="feeds-page" to +page.svelte
- [x] 5.2 Add data-name="app-layout" to +layout.svelte
- [x] 5.3 Add data-name="main-header" to Header.svelte
- [x] 5.4 Add data-name="feed-box" and data-name="load-more" to FeedBox.svelte
- [x] 5.5 Add data-name="feed-tabs" and data-name="tab-button" to FeedTabs.svelte
- [x] 5.6 Add data-name="timeline-view" to TimelineView.svelte
- [x] 5.7 Add data-name="cluster-expansion" to ClusterExpansion.svelte
- [x] 5.8 Add data-name attributes to UI primitives (Button, Card, Link)
- [x] 5.9 Run visual regression tests

## 6. Build and Verification

- [x] 6.1 Run `just nix-build` to verify compilation
- [x] 6.2 Run `nix develop . --command crystal spec`
- [x] 6.3 Run frontend tests `cd frontend && npm run test`
- [x] 6.4 Verify API contracts unchanged (no breaking changes)

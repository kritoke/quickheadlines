## Why

Users want to engage with articles beyond just reading them - many feeds provide comment sections or discussion pages. Currently, QuickHeadlines displays only the article link, forcing users to hunt for discussion links on the source site. Adding native comment and commentary links from feeds improves user engagement.

## What Changes

- Upgrade `fetcher.cr` dependency from `0.7.3` to `0.8.0` to access new comment fields
- Add `comment_url`, `commentary_url`, and `is_discussion_url` fields to backend data model
- Update database schema with new columns
- Update API to expose comment links to frontend
- Add TypeScript types for new fields
- Display subtle inline SVG icons next to articles that open comment/commentary URLs in new tab

## Capabilities

### New Capabilities
- `feed-comments`: Support for displaying comment and commentary links on feed items with inline icons

### Modified Capabilities
- None - this adds new optional data to existing feed items without changing existing behavior

## Impact

- **Backend**: `src/models.cr`, `src/storage/schema.cr`, `src/repositories/feed_repository.cr`, `src/api.cr`, `shard.yml`
- **Frontend**: `frontend/src/lib/types.ts`, `frontend/src/lib/components/FeedBox.svelte`, `frontend/src/lib/components/TimelineView.svelte`
- **Dependencies**: `fetcher.cr` upgraded to `~> 0.8.0`

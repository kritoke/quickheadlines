## 1. Backend - Database & Models

- [x] 1.1 Upgrade fetcher.cr in shard.yml from ~> 0.7.3 to ~> 0.8.0
- [x] 1.2 Update src/models.cr - add comment_url, commentary_url, is_discussion_url to Item record
- [x] 1.3 Update src/storage/schema.cr - add new columns to items table
- [x] 1.4 Run shards install to update dependency

## 2. Backend - Repository & API

- [x] 2.1 Update src/repositories/feed_repository.cr - add new fields to INSERT query
- [x] 2.2 Update src/repositories/feed_repository.cr - add new fields to SELECT query
- [x] 2.3 Update src/api.cr - add comment_url and commentary_url to ItemResponse class
- [x] 2.4 Build Crystal backend to verify changes compile

## 3. Frontend - Types

- [x] 3.1 Update frontend/src/lib/types.ts - add comment_url and commentary_url to ItemResponse interface
- [x] 3.2 Update frontend/src/lib/types.ts - add comment_url and commentary_url to TimelineItemResponse interface
- [x] 3.3 Update frontend/src/lib/types.ts - add comment_url and commentary_url to StoryResponse interface

## 4. Frontend - FeedBox Component

- [x] 4.1 Add inline SVG icons for comment and commentary to FeedBox.svelte
- [x] 4.2 Display icons inline next to article title when URLs are present
- [x] 4.3 Add hover tooltips ("Comments", "Discussion")

## 5. Frontend - TimelineView Component

- [x] 5.1 Add same inline SVG icons to TimelineView.svelte
- [x] 5.2 Display icons inline next to article title when URLs are present

## 6. Build & Test

- [x] 6.1 Run just nix-build to rebuild frontend and backend
- [x] 6.2 Test locally to verify icons appear for feeds with comment URLs
- [x] 6.3 Run frontend tests: cd frontend && npm run test
- [x] 6.4 Run Crystal tests: nix develop . --command crystal spec

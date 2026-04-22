# data-canonical-domain-model

**Owner:** Backend Team  
**Status:** proposed

## Overview

Establish a single authoritative definition for core domain types. Eliminate duplicate `Item` and `TimelineItem` records that exist across `models.cr`, `feed_service.cr`, and `story_repository.cr`. Consolidate into a canonical `QuickHeadlines::Domain` namespace.

## Requirements

### REQ-001: FeedItem Struct
Create `QuickHeadlines::Domain::FeedItem` as the canonical item type:

```crystal
struct QuickHeadlines::Domain::FeedItem
  property id : Int64
  property title : String
  property link : String
  property pub_date : Time?
  property version : String?
  property comment_url : String?
  property commentary_url : String?
  property feed_id : Int64
end
```

### REQ-002: TimelineEntry Struct
Create `QuickHeadlines::Domain::TimelineEntry` as the canonical timeline item type:

```crystal
struct QuickHeadlines::Domain::TimelineEntry
  property id : Int64
  property title : String
  property link : String
  property pub_date : Time?
  property feed_title : String
  property feed_url : String
  property feed_link : String
  property favicon : String?
  property header_color : String?
  property header_text_color : String?
  property header_theme_colors : String?
  property cluster_id : Int64?
  property representative : Bool
  property cluster_size : Int32
end
```

### REQ-003: Remove Duplicate Types
After migration period:
- Remove `record Item` from `models.cr`
- Remove `struct Item` from `feed_service.cr`
- Remove `struct TimelineItem` from `story_repository.cr`
- Remove `record TimelineItem` from `models.cr`
- Remove `record ClusteredTimelineItem` from `models.cr`
- Remove `StoryGroup` record from `models.cr`

### REQ-004: Repository Return Types
`StoryRepository#find_timeline_items` returns `Array(QuickHeadlines::Domain::TimelineEntry)` instead of `Array(TimelineItem)`.

## Acceptance Criteria

- [ ] All repositories return `QuickHeadlines::Domain::TimelineEntry` for timeline queries
- [ ] No duplicate `Item` type definitions exist in the codebase
- [ ] `story_repository.cr` uses the canonical `TimelineEntry` struct
- [ ] `feed_repository.cr` uses the canonical `FeedItem` struct
- [ ] `ClusteredTimelineItem` and `StoryGroup` are removed

## Affected Files

- `src/domain/items.cr` — NEW file with canonical types
- `src/models.cr` — Remove duplicate types
- `src/services/feed_service.cr` — Remove duplicate Item struct
- `src/repositories/story_repository.cr` — Use TimelineEntry
- `src/repositories/feed_repository.cr` — Use FeedItem

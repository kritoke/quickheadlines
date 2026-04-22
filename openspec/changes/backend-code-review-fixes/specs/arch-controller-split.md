# arch-controller-split

**Owner:** Backend Team  
**Status:** proposed

## Overview

Split `FeedsController` (which handles 5 distinct endpoints with different concerns) into focused controllers following Single Responsibility Principle.

## Requirements

### REQ-001: FeedsController — Feed Listing Only
`FeedsController` retains only:
- `GET /api/feeds` — main feed page listing

### REQ-002: ConfigController — Configuration Endpoint
New `ConfigController` handles:
- `GET /api/config` — returns refresh_minutes, item_limit, debug

### REQ-003: TabsController — Tab Listing
New `TabsController` handles:
- `GET /api/tabs` — returns tab list

### REQ-004: HeaderColorController — Color Saving
New `HeaderColorController` handles:
- `POST /api/header_color` — save feed header color override

### REQ-005: FeedPaginationController — Feed Items
New `FeedPaginationController` handles:
- `GET /api/feed_more` — paginated items for a specific feed

### REQ-006: Backward-Compatible Routing
All existing endpoint paths (`/api/feeds`, `/api/feed_more`, `/api/config`, `/api/tabs`, `/api/header_color`) remain identical. Only the class handling each endpoint changes.

## Acceptance Criteria

- [ ] All existing endpoint paths unchanged
- [ ] `GET /api/feeds` handled by `FeedsController`
- [ ] `GET /api/config` handled by `ConfigController`
- [ ] `GET /api/tabs` handled by `TabsController`
- [ ] `POST /api/header_color` handled by `HeaderColorController`
- [ ] `GET /api/feed_more` handled by `FeedPaginationController`
- [ ] Each controller is ≤100 lines

## Affected Files

- `src/controllers/feeds_controller.cr` — Split into 5 controllers
- `src/controllers/config_controller.cr` — NEW
- `src/controllers/tabs_controller.cr` — NEW
- `src/controllers/header_color_controller.cr` — NEW
- `src/controllers/feed_pagination_controller.cr` — NEW

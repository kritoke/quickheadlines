## Why

When users scroll the Timeline view, the app loads more feed items but the experience feels abrupt — new items appear instantly and the list jumps. We should smooth this with a subtle animation and ensure loading more items is reliable. If feasible, persist the set of loaded items so a page refresh keeps the same feed position.

## What Changes

- Implement infinite scroll behavior for the Timeline view that loads additional feed items when the user scrolls near the bottom.
- Add a subtle insert animation (fade+slide) when new items are appended to the feed to reduce visual jank.
- (Optional) Persist loaded feed state (IDs and scroll position) in sessionStorage so a refresh restores the visible items and scroll position.

## Capabilities

### Modified Capabilities
- `timeline-infinite-scroll`: Add incremental loading and animated insertion for timeline feed items

## Impact

- Code: `ui/src/Pages/Timeline.elm`, `ui/src/Components/FeedItem.elm`, and related model/update/msg plumbing
- UI: Timeline scrolling, loading indicator, and item insertion animation

## Capability: timeline-infinite-scroll

### Goal

Enable incremental loading of timeline feed items as the user scrolls, and animate inserted items to reduce visual jank. Optionally support restoring loaded items and scroll position on refresh.

### Requirements

- Load more items when the scroll position reaches within 400px of the bottom or the visible items count is below a threshold.
- Show a loading indicator while fetching more items.
- Append new items without causing the list to jump: animate their entrance with a fade+slide-up over 220ms.
- Implement defensive handling for duplicate items and rapid-firing scroll events (debounce/throttle requests).
- (Optional) Persist: store loaded item IDs and scroll position in `sessionStorage` and restore on mount.

### API Contract

- The timeline page will call an existing feed endpoint with `?offset=<n>&limit=<m>`; ensure backend returns stable ordering and unique IDs.
- Frontend must gracefully handle empty responses (end of feed) and transient errors (show retry control).

### UX Notes

- Reserve vertical space for items when loading if necessary to avoid layout jump, or insert items with CSS transforms so the scroll position is preserved.
- Insert animation: 220ms ease-out, opacity from 0→1 and transform translateY(8px)→0.

### Tests

- Unit: verify `loadMore` triggers when scroll threshold reached and that debounce prevents multiple parallel requests.
- Integration: mock endpoint returns an additional page; verify DOM gains new items and animation classes are applied.

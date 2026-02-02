1. Proposal: describe problem and goals (`proposal.md`) — done
2. Design: animation and UX decisions (`design.md`) — done
3. Spec: capability definition for `timeline-infinite-scroll` (`specs/timeline-infinite-scroll/spec.md`) — done
4. Implementation plan & tasks (`tasks.md`) — done

Implementation checklist
- [x] Wire incremental loading in `ui/src/Pages/Timeline.elm`:
  - [x] Add `LoadMore` message and `loading` flag to the model
  - [x] Implement `requestMore` helper that calls the existing feed endpoint with `offset`/`limit`
  - [x] Throttle/debounce scroll handler to avoid duplicate requests (implemented deduplication and state checks)
  - [x] Append received items to the model while preserving order and deduplicating by ID
- [x] Animate inserted items in `ui/src/Pages/Timeline.elm`:
  - [x] Add CSS classes/Elm transition helper to apply fade + slide-up (300ms ease-out)
  - [x] Ensure animation uses transforms (avoid layout thrash)
- [x] Loading UI:
  - [x] Show spinner at bottom while `loadingMore` is true
  - [x] Show end-of-feed state when an empty page is returned
  - [x] Show error state with retry when fetch fails
- [x] Scroll detection and infinite scroll triggering:
  - [x] Set up IntersectionObserver for sentinel element
  - [x] Fix scroll container layout for proper overflow scrolling
  - [x] Only trigger load when scrolled near bottom (not just sentinel visible)
  - [x] Connect JavaScript port to Elm NearBottom message
- [x] Fix Main.elm subscriptions to use Application.subscriptions (was returning Sub.none)
- [x] Add Font import to Theme.elm (build error fix)
- [x] Fix layout constraints in Layouts/Shared.elm for proper scrolling
- [x] Fix html/body CSS for app-like scrolling behavior
- [x] Tests and validation:
  - [x] Integration: verify DOM insertion and presence of animation class
  - [x] Visual: run Playwright tests for infinite scroll behavior
  - [x] All 6 infinite-scroll tests pass

Remaining (future enhancements):
- [ ] Optional persistence (sessionStorage): store loaded items and scroll position
- [ ] Unit tests for loadMore triggers and debounce behavior
- [ ] Docs & changelog update

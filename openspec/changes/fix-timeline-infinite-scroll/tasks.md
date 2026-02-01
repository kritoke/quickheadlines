1. Proposal: describe problem and goals (`proposal.md`) — done
2. Design: animation and UX decisions (`design.md`) — done
3. Spec: capability definition for `timeline-infinite-scroll` (`specs/timeline-infinite-scroll/spec.md`) — done
4. Implementation plan & tasks (`tasks.md`) — now

Implementation checklist
- [ ] Wire incremental loading in `ui/src/Pages/Timeline.elm`:
  - [ ] Add `LoadMore` message and `loading` flag to the model
  - [ ] Implement `requestMore` helper that calls the existing feed endpoint with `offset`/`limit`
  - [ ] Throttle/debounce scroll handler to avoid duplicate requests
  - [ ] Append received items to the model while preserving order and deduplicating by ID
- [ ] Animate inserted items in `ui/src/Components/FeedItem.elm` or wrapper:
  - [ ] Add CSS classes/Elm transition helper to apply fade + slide-up (220ms ease-out)
  - [ ] Ensure animation uses transforms (avoid layout thrash)
- [ ] Loading UI:
  - [ ] Show spinner at bottom while `loading` is true
  - [ ] Show end-of-feed state when an empty page is returned
  - [ ] Show error state with retry when fetch fails
- [ ] Optional persistence (sessionStorage):
  - [ ] On mount, check `sessionStorage` for stored `loadedIds` and `scrollY`, restore items if present
  - [ ] On successful load, persist `loadedIds` and current scroll position
  - [ ] Provide a clear policy for expiration / invalidation (e.g., ttl per session)
- [ ] Tests and validation:
  - [ ] Unit test: `loadMore` triggers and debounce works; duplicate requests prevented
  - [ ] Integration: mock endpoint returns a page; verify DOM insertion and presence of animation class
  - [ ] Visual: run `elm-land build` and spot-check animation in Playwright if available
- [ ] Docs & changelog:
  - [ ] Add short note to changelog about timeline infinite scroll behavior and persistence (if enabled)

5. Add persistence (optional) to store loaded items and scroll position in `sessionStorage` — pending (covered above)
6. Add tests for loading behavior and animation timing — pending (covered above)
7. Update changelog and docs — pending

## Implementation: timeline-infinite-scroll

### Summary

Implement incremental loading on the Timeline page, animate inserted items (fade + slide-up, 220ms ease-out), and add a small loading indicator. Optionally persist loaded item IDs and scroll position in `sessionStorage`.

### Files to change

- `ui/src/Pages/Timeline.elm` — add load-more wiring, messages, and scroll handler
- `ui/src/Components/FeedItem.elm` — add animation classes/wrapper or provide transition hook
- `ui/src/Styles/timeline.css` (or existing style file) — add animation CSS for fade+slide

### Implementation Steps (one artifact)

1) Model & Msg

- Add `loading : Bool`, `endOfFeed : Bool`, and `loadedIds : Set Int` (or String) to the Timeline model
- Add `LoadMore` and `LoadedMore (Result Http.Error (List FeedItem))` messages

2) Request helper

- Create `requestMore : Int -> Cmd Msg` which calls the feed endpoint with `offset` and `limit` and maps response to `LoadedMore`
- Ensure response parsing deduplicates by ID

3) Scroll handler

- Add a throttled scroll listener (Debounce 200ms) that dispatches `LoadMore` when scroll position is within 400px of bottom and `loading` is false and `endOfFeed` is false

4) Update logic

- On `LoadMore`: set `loading = true` and issue `requestMore offset limit`
- On `LoadedMore (Ok items)`: append non-duplicate items to model list, set `loading = false`; if items is empty, set `endOfFeed = true`
- On `LoadedMore (Err _)`: set `loading = false` and set an `error` flag / message

5) Animation

- For insertion animation, add a lightweight wrapper element around each `FeedItem` that applies a CSS class on mount (e.g., `inserted`) that triggers opacity/transform transition. Prefer CSS transforms for performance.
- Alternative: use Elm animation helper library if present, but CSS is simplest and reliable.

6) Loading UI and UX

- While `loading` show a small spinner at the bottom of the feed
- When `endOfFeed` true, show a subtle "End of feed" marker
- On error, show retry control that re-dispatches `LoadMore`

7) Optional: sessionStorage persistence

- On successful append, save `loadedIds` and `window.scrollY` into `sessionStorage` under `qh:timeline:<timeline-id>`
- On mount, if persisted state exists, try restoring items by requesting missing IDs or refetching pages until stored IDs are satisfied; then restore scroll position
- Keep persistence optional behind a feature flag to avoid complexity initially

### Tests / Verification

- Unit test: ensure `LoadMore` results in a single request when throttled
- Integration: mock HTTP page response and assert DOM grows with `.inserted` class applied and spinner shown/hidden

### Notes

- Deduplicate by feed item ID — backend must guarantee stable ordering and unique IDs. If not, build a client-side dedupe by `id` field.
- Keep `limit` small (e.g., 10–20) to keep animations snappy and avoid long blocking fetches

### Next steps

- If you want, I can now draft the Elm changes (create a focused patch for `Timeline.elm` and `FeedItem.elm`) implementing the above. Reply: "Yes — implement Elm code" or "No — modify plan".

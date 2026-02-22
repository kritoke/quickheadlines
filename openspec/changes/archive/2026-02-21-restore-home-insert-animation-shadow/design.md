## Design: Restore Home Insert Animation & Feed Card Shadow

This design describes how to implement two small UI behaviors while respecting the OpenSpec Semantic Metadata Standard and Elm-first principle.

1) Elm Inline Animation
- Detect inserted item IDs in the Home page Elm model (already tracked as `insertedIds`).
- When rendering a feed item, if its id is in `insertedIds`, add an inline style attribute:
  `animation: qh-insert 220ms ease-out both; will-change: opacity, transform;`
- Apply the style on the visible anchor or headline element (`[data-display-link]` or similar) so transforms/opacity affect visible content.

2) CSS changes
- Add `@keyframes qh-insert` to `public/timeline.css` with translateY 8px → 0 and opacity 0 → 1.
- Add attribute-selector rules for `[data-semantic="feed-card"]` and its `::after` pseudo-element to render the bottom gradient. Keep existing `.feed-box` rules as fallbacks for older elements.

3) Client-side scroll observer
- Update `index.html` script:
  - Query `[data-semantic="feed-card"]` to find feed cards.
  - For each card, find a scrollable descendant: prefer `[data-semantic="feed-body"]`, otherwise use the existing findScrollableDescendant heuristic.
  - Attach scroll/resize listeners to toggle `is-at-bottom` class on the card element.

4) Timeline parity
- Make the Timeline page render inserted items with the same inline animation for consistency.

5) Tests & Verification
- Update Playwright diagnostics to target attribute selectors and to check computed animation-name or inline style presence.

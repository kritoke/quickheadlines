## Why

The Home feed lost two small but important UI behaviors present in v0.4.0: (1) a short insert animation when new items are appended via "Load More", and (2) a bottom gradient shadow on feed cards that indicates there is more scrollable content. Restoring these improves discoverability and gives users a clear affordance for new content.

## What Changes

- Apply a 220ms `qh-insert` animation to newly appended feed items on the Home page via Elm-first inline styles.
- Add semantic CSS selectors that target `Theme.semantic` attributes (e.g. `[data-semantic="feed-card"]`) for the gradient shadow and animation fallbacks.
- Update the small client-side scroll observer (index.html) to query `[data-semantic="feed-card"]` and toggle an `is-at-bottom` class based on the scrollable descendant's position.
- Ensure Timeline page uses the same `qh-insert` animation via Elm inline styles for parity.

## Capabilities

### New Capabilities
- `home-insert-animation`: Ensures newly appended Home feed items animate on entry (qh-insert 220ms) and exposes semantic hooks for testing.
- `feed-card-scroll-shadow`: Adds a bottom gradient shadow to feed cards that toggles when not scrolled to bottom; accessible via `[data-semantic="feed-card"]::after`.

### Modified Capabilities
- `ui-theming`: Update CSS in `public/timeline.css` to include attribute-selector equivalents for existing rules that previously targeted `.feed-box`/`.feed-body` classnames. This is not a functional change to the theme API but adjusts selectors to follow the Semantic Metadata Standard.

## Impact

- Files modified: `ui/src/Pages/Home_.elm`, `ui/src/Pages/Timeline.elm`, `public/timeline.css`, `index.html` (client script). Tests: `ui/tests/*` may be updated or rely on new selectors.
- No backend or API changes.
- No breaking changes to public APIs. This change adheres to the Semantic Metadata Standard and avoids overriding elm-ui generated classes.

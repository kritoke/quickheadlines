## Why

The current header navigation fails when too many feed tabs exist. The horizontal scroll is a surrender to the problem—users must discover hidden tabs through scrolling rather than having content come to them. Additionally, the header consumes excessive vertical space with a two-row layout (logo row + tabs row), and the mobile experience forces users to swipe horizontally to find categories. The current design lacks hierarchy and forces all action buttons (search, timeline, effects, theme) into a crowded icon bar.

## What Changes

- **Create `TabSelector.svelte`**: Adaptive tab component that shows tabs inline on desktop (up to 5) with a "More" dropdown for overflow, and collapses to a selector on mobile.
- **Create `MobileTabSheet.svelte`**: Bottom sheet modal for mobile tab selection, replacing the horizontal scroll with a thumb-friendly full-screen selector.
- **Refactor `AppHeader.svelte`**: Remove the separate `tabContent` snippet and second header row. Integrate tabs directly into a single-row header layout. Reduce header height from ~100px to ~56px on desktop.
- **Delete `FeedTabs.svelte`**: Remove the legacy pill-style tab component, replaced entirely by `TabSelector`.
- **Update `+page.svelte`**: Pass `tabs` and `activeTab` directly to `AppHeader` instead of using the `tabContent` snippet.
- **Keep action buttons visible**: Search, timeline toggle, effects toggle, and theme picker remain as individual buttons (not collapsed into a menu).

## Capabilities

### New Capabilities
- `adaptive-tab-selector`: Tab navigation that adapts display based on viewport and tab count. On desktop: inline text links with underline indicator and "More" dropdown for overflow. On mobile: dropdown button that opens a bottom sheet for full tab selection.
- `mobile-tab-sheet`: Thumb-friendly bottom sheet interface for selecting categories on mobile devices. Slides up from bottom with backdrop, full-width tap targets, and checkmark indicator for active tab.

### Modified Capabilities
- `ui-header-styles`: Header layout requirements updated to single-row design with integrated tabs. The spec's visual requirements for pill backgrounds and horizontal scrolling are replaced with adaptive dropdown behavior.

## Impact

- **Frontend Components**: New files `TabSelector.svelte`, `MobileTabSheet.svelte`. Modified `AppHeader.svelte`, `+page.svelte`. Deleted `FeedTabs.svelte`.
- **Tests**: `AppHeader.test.ts` requires updates for new component structure.
- **CSS/Tailwind**: No new utility classes required. Uses existing dropdown and animation patterns.
- **No breaking API changes**: Tab selection callback maintains same URL navigation behavior.

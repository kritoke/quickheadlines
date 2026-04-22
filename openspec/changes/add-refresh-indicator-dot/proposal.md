## Why

The refresh indicator dot (a subtle pulsing indicator next to the update timestamp) was previously present but is currently missing from the timeline page and lacks visual enhancement. Users need a clear, visible indicator when the app is refreshing feeds in the background to provide feedback that the system is actively updating. This improves perceived responsiveness and reduces confusion about whether background refresh is occurring.

## What Changes

- **Timeline page (`frontend/src/routes/timeline/+page.svelte`)**: Add refresh indicator dot in the header metadata section, displayed when `isRefreshing` or `isClustering` is true
- **Timeline page**: Add `lastUpdated` timestamp state to track when timeline was last refreshed, displayed alongside item count
- **Feeds page (`frontend/src/routes/+page.svelte`)**: Enhance existing refresh indicator with a subtle glow effect for better visibility
- **Both pages**: Use consistent visual styling with a blue pulsing dot enhanced with a soft shadow glow (`shadow-[0_0_6px_rgba(59,130,246,0.6)]`)

## Capabilities

### New Capabilities
- `refresh-indicator-ui`: Visual refresh state indicator with pulsing glow effect displayed in header metadata during background refresh operations

### Modified Capabilities
- None (this is a UI enhancement without requirement changes to existing capabilities)

## Impact

**Affected Code:**
- `frontend/src/routes/timeline/+page.svelte` - Adds `lastUpdated` state, updates metadata snippet
- `frontend/src/routes/+page.svelte` - Updates existing refresh indicator styling

**Dependencies:**
- Tailwind CSS for glow effect (arbitrary value syntax)
- Existing `isRefreshing` and `isClustering` state already present in both pages
- No backend changes required - uses existing refresh state management

**Systems:**
- Svelte 5 frontend only
- No Crystal backend changes
- No database schema changes

**Testing:**
- Manual QA in both light and dark modes
- Verify dot visibility during auto-refresh cycles
- Confirm timeline shows item count + timestamp + indicator

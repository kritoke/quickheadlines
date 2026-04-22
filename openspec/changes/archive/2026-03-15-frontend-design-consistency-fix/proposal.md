## Why

The QuickHeadlines frontend has severe visual inconsistencies between the Timeline and Feed views, with mismatched container widths and a cramped theme picker dropdown. These inconsistencies create cognitive dissonance for users and undermine the professional polish expected from a Steve Jobs-era Apple-quality interface. The timeline view uses `max-w-[1400px]` while the feed view arbitrarily limits to `75%` on desktop, and the theme modal lacks proper padding causing a claustrophobic experience.

## What Changes

- **Timeline Page**: Unify max-width container constraints with feed page for visual consistency
- **Feed Page**: Remove `max-w-[75%]` constraint to match timeline's `max-w-[1400px]` behavior
- **FeedBox Component**: Replace hardcoded `h-[500px]` height with responsive width-based constraints
- **ThemePicker Dropdown**: Add consistent padding using design system tokens (12px horizontal, 8px vertical)
- **Grid Layout**: Ensure both views use identical responsive breakpoints and spacing

## Capabilities

### New Capabilities
- `frontend-layout-consistency`: Establishes unified container width standards across all pages
- `theme-modal-padding`: Improves theme picker dropdown with proper spacing

### Modified Capabilities
- None - this is purely a frontend UI consistency improvement

## Impact

**Files Modified:**
- `frontend/src/routes/+page.svelte` - Feed view container
- `frontend/src/routes/timeline/+page.svelte` - Timeline view container  
- `frontend/src/lib/components/FeedBox.svelte` - Feed card sizing
- `frontend/src/lib/components/ThemePicker.svelte` - Dropdown padding

**No Breaking Changes**: This is purely visual/UX improvement with no API or behavior changes.

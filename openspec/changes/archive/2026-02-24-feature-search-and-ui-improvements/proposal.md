## Why

Users need to quickly find specific articles across all feeds. With potentially many feeds and items, searching by title or content becomes essential for usability. Additionally, desktop users with wide screens can benefit from more content density.

## What Changes

1. **4th Column Grid** - Add a 4th column for extra-wide desktop screens (≥1280px) for better content density
2. **CoolMode Cleanup** - Remove unused Svelte 4 `onDestroy` import from CoolMode.svelte
3. **Search Feature** - Add real-time search across feeds and timeline
4. **Optimistic UI** - Improve perceived performance with optimistic updates

## Capabilities

### New Capabilities
- **Search**: Real-time search across feed titles, item titles, and item descriptions
- **4-Column Layout**: Display 4 feed cards in a row on extra-wide screens

### Modified Capabilities
- **Tab Switching**: Keep cached content visible while loading new tab (optimistic)
- **Load More**: Show placeholder while loading more items (optimistic)
- **Background Refresh**: Subtle non-intrusive indicator during refresh

## Impact

### Frontend Changes
- `frontend/src/routes/+page.svelte` - Add search bar, 4th column grid, optimistic tab switching
- `frontend/src/routes/timeline/+page.svelte` - Add search bar, optimistic loading
- `frontend/src/lib/components/CoolMode.svelte` - Remove unused onDestroy import
- New search component (inline or separate)

### No Breaking Changes
- All existing functionality preserved
- Search is additive (no changes to default view)
- Grid layout degrades gracefully on smaller screens

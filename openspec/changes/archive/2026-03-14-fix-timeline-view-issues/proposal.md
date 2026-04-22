## Why

The TimelineView component has multiple functional bugs introduced during recent refactoring that break core user features, including broken cluster expansion in multi-column layouts and incomplete 4-column support. Additionally, the theme implementation uses anti-patterns like `!important` declarations that violate Apple's design principles and create maintenance issues.

## What Changes

### Critical Bug Fixes (Phase 1)
- **Fix cluster expansion logic**: Change `expandedClusterId === item.id` to `expandedClusterId === item.cluster_id` in TimelineView.svelte line 124 to enable proper cluster expansion in multi-column layouts
- **Complete 4-column support**: Update `getGridClass()` function to properly support all column counts (1-4) including `xl:grid-cols-4` for 4 columns
- **Restore hover UX**: Revert hover state from opacity change back to background color change for better readability and visual feedback
- **Fix grid gap**: Replace incorrect use of spacing token as CSS class with proper Tailwind gap utility classes

### Theme Implementation Improvements (Phase 2)
- **Eliminate !important declarations**: Refactor CSS to use more specific selectors instead of `!important` for custom theme overrides
- **Standardize semantic class usage**: Ensure consistent application of semantic theme classes across all components
- **Improve theme switching performance**: Reduce DOM manipulation overhead during theme changes

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `timeline-page-layout`: Update to require proper 4-column grid support and fix cluster expansion behavior
- `semantic-theme-tokens`: Update to document elimination of `!important` anti-pattern

## Impact

### Affected Code
- `frontend/src/lib/components/TimelineView.svelte` - Fix critical bugs
- `frontend/src/app.css` - Refactor theme overrides to eliminate !important
- `frontend/src/lib/stores/theme.svelte.ts` - Minor performance improvements

### Preserved Features
- Mouse cursor effects (effects toggle)
- Grid layout on timeline view
- All 10 themes including Hot Dog Stand
- Date grouping and sorting behavior

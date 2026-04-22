## Why

The ThemePicker component has performance issues (recomputes gradient strings on every render), inconsistent accessibility support compared to LayoutPicker (which uses bits-ui DropdownMenu), and missing keyboard navigation. Additionally, theme color functions in the store recreate large lookup objects on every call, causing unnecessary memory allocations.

## What Changes

1. **Migrate ThemePicker to bits-ui DropdownMenu** - Use same component library as LayoutPicker for consistent accessibility (ARIA, keyboard nav, focus management)
2. **Cache theme preview gradients** - Use `$derived` Map to avoid recomputing 13 gradient strings per render
3. **Cache theme color lookups** - Move color lookup tables to module-level `$state` objects to prevent recreation on each function call
4. **Fix type safety** - Use proper `ThemeStyle` type on `selectTheme` parameter
5. **Add localStorage error handling** - Wrap localStorage calls in try/catch for private browsing compatibility

## Capabilities

### New Capabilities
- `theme-picker-accessibility`: Consistent keyboard navigation and ARIA support via bits-ui integration

### Modified Capabilities
- `theme-store-performance`: Internal optimization - no external API changes

## Impact

**Affected files:**
- `frontend/src/lib/components/ThemePicker.svelte` - Migrate to bits-ui, add caching
- `frontend/src/lib/stores/theme.svelte.ts` - Add cached color lookups, error handling

**Dependencies:**
- bits-ui already installed (used by LayoutPicker, FeedTabs, BitsSearchModal)

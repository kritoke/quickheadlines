## Context

The ThemePicker component currently uses a custom dropdown implementation with manual click handlers and state management. In contrast, LayoutPicker uses bits-ui's DropdownMenu component, which provides:
- Proper ARIA attributes (role, aria-expanded, aria-haspopup)
- Keyboard navigation (Escape to close, arrow key navigation)
- Focus management
- Screen reader support

Additionally, the theme store (`theme.svelte.ts`) has performance issues where color lookup functions recreate large objects on every call.

## Goals / Non-Goals

**Goals:**
1. Migrate ThemePicker to use bits-ui DropdownMenu for consistent accessibility
2. Cache theme preview gradients using `$derived` to avoid 13 recomputations per render
3. Cache color lookups at module level to prevent object recreation
4. Add proper TypeScript types
5. Add localStorage error handling

**Non-Goals:**
- No changes to external API (theme selection behavior unchanged)
- No changes to CSS/Tailwind classes (visual appearance unchanged)
- No new themes added

## Decisions

### 1. Use bits-ui DropdownMenu for ThemePicker

**Alternative considered:** Keep custom dropdown, add manual ARIA/keyboard support

**Decision:** Migrate to bits-ui DropdownMenu

**Rationale:**
- Already used in LayoutPicker, FeedTabs, BitsSearchModal (consistency)
- Handles all accessibility concerns automatically
- Reduces code duplication (no manual click-outside handling)
- Better tested (battle-tested headless component)

### 2. Cache Color Lookups at Module Level

**Alternative considered:** Use `$derived` in each component

**Decision:** Use module-level `$state` for cached color objects

**Rationale:**
- Single cache serves all components (layout, theme pickers, scroll buttons)
- `$state` is reactive and updates automatically
- Avoids recreating lookup tables on every function call

### 3. Theme Preview Caching Strategy

**Alternative considered:** Pre-compute in theme store

**Decision:** Use `$derived` in ThemePicker component

**Rationale:**
- Gradient strings only needed in ThemePicker
- Component-level `$derived` is appropriate scope
- Keeps store focused on theme state, not presentation

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| bits-ui API changes | Version is stable (v2.16.2), DropdownMenu API is well-established |
| Migration breaks existing UX | Keep visual appearance identical; only change underlying implementation |
| Gradient caching causes stale data | Use `$derived` which auto-updates when `themeState.theme` changes |

## Migration Plan

1. Update `theme.svelte.ts`:
   - Add module-level cached color objects
   - Wrap localStorage calls in try/catch
   - Fix `getThemePreview` type parameter

2. Update `ThemePicker.svelte`:
   - Import DropdownMenu from bits-ui
   - Replace custom dropdown with bits-ui components
   - Add `$derived` for gradient cache
   - Remove manual click-outside handling

3. Verify:
   - Run `npm run check` for type safety
   - Manual test keyboard navigation
   - Verify visual appearance unchanged

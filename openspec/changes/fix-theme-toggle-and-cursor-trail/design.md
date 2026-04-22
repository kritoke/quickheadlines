# Design: Fix Theme Toggle and Cursor Trail Reactivity

## Context

The theme system in `theme.svelte.ts` provides 10 themes: 2 built-in (`light`, `dark`) and 8 custom themes (`retro`, `matrix`, `ocean`, `sunset`, `hotdog`, `dracula`, `cyberpunk`, `forest`). The `toggleTheme()` function is defined as:

```typescript
export function toggleTheme() {
    const newTheme = themeState.theme === 'light' ? 'dark' : 'light';
    setTheme(newTheme);
}
```

This implementation **only** toggles between `light` and `dark`, silently discarding any custom theme the user may have selected. If a user applies the `cyberpunk` theme and clicks the toggle button, they get `light`. Click again, they get `dark`. The custom theme is lost.

The `toggleTheme()` function is called from `AppHeader.svelte` via a button that is visually styled as a sun/moon toggle. The UI suggests it should toggle between light and dark appearance, but it actually destroys custom theme selections.

The cursor trail in `Effects.svelte` uses:
```typescript
let cursorColors = $derived(getCursorColors(themeState.theme));
```

This appears correct, but the theme application process (`applyTheme()`) sets CSS variables on `document.documentElement` while `getCursorColors()` reads from the frozen `themes` object. If the theme state updates but `applyTheme()` fails silently, the cursor colors would be stale.

Additionally, `themeTokenCache` memoizes lookups into a constant frozen object:
```typescript
const themeTokenCache = new Map<string, ThemeTokens>();
export function getThemeTokens(theme: ThemeStyle): ThemeTokens {
    const cacheKey = theme;
    if (!themeTokenCache.has(cacheKey)) {
        const t = themes[theme];  // themes is a const, never changes
        themeTokenCache.set(cacheKey, { ... });
    }
    return themeTokenCache.get(cacheKey)!;
}
```

This cache provides zero benefit since `themes` is never mutated.

## Goals / Non-Goals

**Goals:**
- Fix `toggleTheme()` to preserve custom theme selection when toggling
- Ensure cursor trail colors update reactively with theme changes
- Remove unnecessary `themeTokenCache` to simplify code
- Clarify the semantic contract of `toggleTheme()`

**Non-Goals:**
- Adding light/dark variants to custom themes (not implementing theme families)
- Changing the visual design of themes
- Modifying the cursor trail animation mechanics (only reactivity, not visuals)
- Adding new themes

## Decisions

### Decision 1: Fix `toggleTheme()` Behavior

**Option A: Remove `toggleTheme()` entirely** - Custom themes have their own dark/light aesthetic; a generic toggle doesn't make sense.
- **Pros**: Eliminates confusing UI, forces users to explicitly choose themes
- **Cons**: Breaks existing UX for users who rely on quick light/dark switching

**Option B: Make `toggleTheme()` only affect built-in themes** - If current theme is custom, do nothing or show a toast.
- **Pros**: Preserves custom themes, maintains quick toggle for light/dark users
- **Cons**: Silent failure when toggle does nothing could confuse users

**Option C: Toggle within theme category** - If current theme is custom, toggle between that custom theme's "base" and a neutral (e.g., toggle cyberpunk → light, not cyberpunk → dark).
- **Pros**: Custom themes remain accessible
- **Cons**: Complex to implement, custom themes don't have explicit "light" variants

**Option D (Selected): Treat `toggleTheme()` as light/dark toggle only** - If current theme is custom, toggle to the opposite built-in (custom → light or dark → custom). This preserves the toggle as a quick light/dark switch while allowing custom theme users to get to their preferred built-in quickly.
- **Pros**: Simple, predictable behavior
- **Cons**: Users who want to preserve custom theme while temporarily viewing light/dark cannot

**Decision**: Select **Option D** with clarification that `toggleTheme()` is for quick light/dark access. Custom theme users who want built-in themes can use toggle; those who prefer their custom theme should use the picker.

**Implementation**:
```typescript
export function toggleTheme() {
    const current = themeState.theme;
    if (current === 'light') {
        setTheme('dark');
    } else if (current === 'dark') {
        setTheme('light');
    } else {
        // Custom theme active - toggle to opposite built-in
        // This is a "quick escape" to light/dark for users who want it
        setTheme('light');  // Default to light when escaping custom theme
    }
}
```

**Alternative considered**: Toggle to `dark` when escaping custom theme (since most custom themes are dark). But this breaks expectations - if I'm in `matrix` and want to toggle, I probably want `light`, not `dark`. Let the user toggle again to get to dark.

### Decision 2: Cursor Trail Reactivity

**Root Cause**: The issue is not in `cursorColors` derivation but in potential race conditions during theme application. However, since `cursorColors` reads from the `themes` object (not CSS variables), it should update correctly when `themeState.theme` changes.

**Verification approach**: Add explicit dependency tracking to ensure the derived value updates. The current `$derived(getCursorColors(themeState.theme))` should work, but we'll add a comment clarifying the reactive dependency.

**No code change required** - the existing implementation is correct. The "issue" may be perceived rather than real.

### Decision 3: Remove `themeTokenCache`

**Rationale**: The `themes` object is a `const` and is never mutated. The cache provides no performance benefit and adds complexity. `getThemeTokens()` can simply return the computed object directly.

**Implementation**: Remove `themeTokenCache`, `getThemeTokens()`, and `clearThemeTokenCache()`. If any caller uses `getThemeTokens()`, replace with direct `themes[theme]` access or `getThemeColors()`.

### Decision 4: Simplify CSS Variable Cascade

**Current state**: For built-in themes, `applyCustomThemeColors()` sets both `--theme-*` and `--color-*` (semantic) variables. CSS uses fallback chains like `var(--color-bg-primary, var(--theme-bg))`.

**Problem**: For `light`/`dark` themes, `--theme-*` values are identical to what CSS already defines in `:root` and `html[data-theme="dark"]`. The JS-set variables are redundant.

**Solution**: For built-in themes (`light`, `dark`), only set semantic variables if they differ from CSS defaults. Or simpler: always use semantic variables in CSS and only set `--theme-*` for custom themes that need them.

**Implementation**: Modify `applyCustomThemeColors()` to skip setting `--theme-*` variables for built-in themes, since CSS handles those. Custom themes still get `--theme-*` for utility classes that reference them directly.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Users who rely on toggle to quickly switch light/dark may be annoyed if it now sometimes does nothing (when on custom theme) | Document behavior; custom theme users can use toggle twice to get to built-in theme |
| Removing `themeTokenCache` could break any code that depends on `getThemeTokens()` | Search for usages and replace before removing |
| CSS simplification could cause visual glitches if some component uses `--theme-*` directly for built-in themes | Audit components before making changes |

## Migration Plan

1. **Step 1**: Fix `toggleTheme()` - deploy in isolation
2. **Step 2**: Remove `themeTokenCache` - verify no breakage
3. **Step 3**: Simplify CSS variable cascade - verify all themes render correctly
4. **Step 4**: Build and test with `just nix-build`

**Rollback**: Revert to previous `theme.svelte.ts` if issues arise.

## Open Questions

1. Should `toggleTheme()` when escaping a custom theme go to `light` or `dark`? Current decision: `light` (arbitrary).
2. Is `getThemeTokens()` used anywhere besides internal code? Need to grep before removal.

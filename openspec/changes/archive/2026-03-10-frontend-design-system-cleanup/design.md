## Context

The frontend has a well-structured TypeScript theme store (`theme.svelte.ts`) with 13 themes defined using a `ThemeColors` interface, but the CSS (`app.css`) duplicates these values with hardcoded blocks and `!important` overrides. Components like `FeedBox.svelte` have 10-15 inline Tailwind class bindings instead of using the existing unused `Card.svelte` component.

**Current state:**
- `app.css`: 441 lines (60+ lines are Hot Dog Stand overrides alone)
- `theme.svelte.ts`: 6 getter functions with overlapping return values
- Components: No consistency in how they apply theme styling

**Constraints:**
- Hot Dog Stand theme must remain
- Effects button (Svelte spring physics) must not be modified
- All 13 themes preserved

## Goals / Non-Goals

**Goals:**
- Remove all hardcoded theme CSS blocks from `app.css`
- Consolidate 6 theme getter functions into single `getThemeTokens()`
- Update FeedBox to use `<Card>` component

**Non-Goals:**
- Add new themes or features
- Modify effects button behavior
- Change any theme's visual appearance
- Refactor the Svelte 5 state management

## Decisions

### 1. CSS Variables as Source of Truth
**Decision**: CSS variables set by JS `applyTheme()` become the single source for theme colors.

**Rationale**: The JS already sets `--theme-bg`, `--theme-accent`, etc. Components can use `var(--theme-accent)` instead of importing theme functions. Reduces JS → CSS prop drilling.

**Alternative considered**: Keep inline styles from JS getters. Rejected - harder to maintain, inconsistent with CSS-first styling.

### 2. Single Token Getter Function
**Decision**: Replace `getThemeColors()`, `getThemeAccentColors()`, `getCursorColors()`, `getScrollButtonColors()`, `getDotIndicatorColors()`, `getThemePreview()` with single `getThemeTokens(theme)`.

**Rationale**: Reduces imports, ensures consistency, single source of truth.

**Alternative considered**: Keep separate functions. Rejected - 6 functions with overlapping data is unnecessary.

### 3. Card Component Usage
**Decision**: `FeedBox.svelte` uses `<Card>` from `$lib/components/ui/Card.svelte` with appropriate props.

**Rationale**: Component already exists, reduces 12+ class bindings to 1-2 props.

**Alternative considered**: Create new `FeedCard` wrapper. Rejected - unnecessary indirection.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Removing CSS overrides breaks Hot Dog Stand | JS theme values are identical; CSS variables handle it |
| Components break if they depend on specific class names | Update all callers to new token function |
| Visual regression | Run screenshot tests, verify themes look identical |

## Migration Plan

1. Update `theme.svelte.ts` with `getThemeTokens()` function
2. Update all callers to use new function
3. Remove theme blocks from `app.css` (lines 200-440)
4. Verify `just nix-build` succeeds
5. Run screenshot tests to verify no visual changes

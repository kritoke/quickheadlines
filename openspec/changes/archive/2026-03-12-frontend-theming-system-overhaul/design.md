## Context

### Current State
The frontend theming system has a fundamental architecture problem:

1. **Theme values defined in JavaScript** (`theme.svelte.ts`) - Contains `themes` object with all color definitions
2. **CSS variables set from JS** - `applyTheme()` sets `--theme-bg`, `--theme-text`, etc. on document root
3. **CSS tries to override Tailwind classes** - 40+ `html.custom-theme` selectors attempt to force CSS variables onto Tailwind utilities using `!important`
4. **Broken approach** - This violates CSS cascade and the existing `theme-tokens` spec requirement for "Minimal CSS Theme Blocks"

### Constraints
- Must maintain backward compatibility with existing theme system (10 themes)
- Must work with Tailwind CSS utilities
- Must support dark mode via Tailwind's `dark:` modifier
- No breaking changes to component APIs during Phase 1

## Goals / Non-Goals

**Goals:**
1. Replace all `!important` overrides with proper semantic CSS custom properties
2. Create semantic token layer mapped to theme values
3. Reduce app.css from ~276 lines to ~120 lines (remove theme-specific blocks)
4. Single source of truth: JS store → CSS variables only, no duplicate definitions

**Non-Goals:**
- Component refactoring (Phase 2+)
- Adding new themes
- Changing component props/APIs
- Accessibility improvements (separate workstream)

## Decisions

### Decision 1: Semantic Token Layer
**Choice:** Create semantic CSS custom properties (e.g., `--color-bg-primary`, `--color-text-secondary`) that map to theme values, rather than trying to override Tailwind utilities.

**Rationale:** Tailwind utilities work with CSS cascade. Instead of overriding `bg-white`, provide semantic alternatives that components opt into.

**Alternative considered:** Remove Tailwind, use pure CSS - Rejected due to migration cost and existing component code.

### Decision 2: Token Mapping Strategy
**Choice:** Add semantic tokens to `themes` object in `theme.svelte.ts` and set them via CSS variables alongside theme-specific values.

```typescript
// In theme.svelte.ts - extend ThemeColors interface
const themes = {
  light: {
    // ... existing values
    semantic: {
      '--color-bg-primary': '#ffffff',
      '--color-bg-secondary': '#f1f5f9',
      '--color-text-primary': '#0f172a',
      '--color-text-secondary': '#64748b',
      '--color-border': '#e2e8f0',
      '--color-accent': '#3b82f6',
    }
  },
  // ... other themes
}
```

**Rationale:** Keeps all theme data in one place (JS store), allows CSS to use semantic names without hardcoding.

### Decision 3: CSS Variable Setting
**Choice:** Modify `applyTheme()` to set both theme-specific AND semantic tokens:

```typescript
function applyCustomThemeColors(theme: ThemeStyle) {
  const t = themes[theme];
  
  // Theme-specific (kept for backward compat)
  document.documentElement.style.setProperty('--theme-bg', t.bg);
  document.documentElement.style.setProperty('--theme-text', t.text);
  // ...
  
  // Semantic tokens (NEW)
  if (t.semantic) {
    Object.entries(t.semantic).forEach(([key, value]) => {
      document.documentElement.style.setProperty(key, value);
    });
  }
}
```

**Rationale:** Gradual rollout - components can opt into semantic classes one at a time.

### Decision 4: Component Migration Pattern
**Choice:** Components use semantic classes that consume CSS variables:

```svelte
<!-- Before (broken approach) -->
<div class="bg-white dark:bg-slate-900 text-slate-900 dark:text-white">

<!-- After (semantic approach) -->
<div class="theme-bg-primary theme-text-primary">
```

With CSS:
```css
.theme-bg-primary {
  background-color: var(--color-bg-primary, var(--theme-bg));
}

.theme-text-primary {
  color: var(--color-text-primary, var(--theme-text));
}
```

**Rationale:** Fallback to theme-specific vars maintains backward compat during migration.

## Risks / Trade-offs

**[Risk] Components may break during migration** → **Mitigation:** CSS fallbacks ensure old Tailwind classes still work. Phase 1 only changes CSS/app.css, components remain unchanged initially.

**[Risk] Semantic tokens not comprehensive enough** → **Mitigation:** Start with core tokens (bg, text, border, accent), add more as needed during component migration.

**[Risk] Performance overhead of CSS variables** → **Mitigation:** CSS variables are performant. Only set on theme change, not per-frame. Browser compositor handles efficiently.

**[Risk] Token naming conflicts with existing CSS** → **Mitigation:** Use `color-` prefix to avoid Tailwind collision, verify no conflicts during implementation.

## Migration Plan

### Phase 1A: Foundation (This Work)
1. Add semantic tokens to `themes` object
2. Update `applyTheme()` to set semantic CSS variables
3. Add semantic utility classes to app.css (with fallbacks)
4. Remove `html.custom-theme` override blocks (~40 selectors)
5. Verify app builds and runs correctly

### Phase 1B: Validation
1. Test all 10 themes visually
2. Verify dark mode toggle works
3. Check component rendering in both modes

### Phase 2: Component Migration (Future)
1. Update components to use semantic classes
2. Remove Tailwind utility overrides where semantic equivalents exist
3. Verify no visual regressions

## Open Questions

1. **Should we keep or remove the old `--theme-bg` variables?**
   - Recommendation: Keep for backward compat with existing code that directly references them

2. **How to handle components that need different bg for different contexts?**
   - Create semantic variants: `--color-bg-card`, `--color-bg-header`, etc.

3. **Should we deprecate the direct CSS variable references in components?**
   - Yes, mark as deprecated in code comments, full removal in Phase 3

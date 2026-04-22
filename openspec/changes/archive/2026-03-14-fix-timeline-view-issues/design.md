## Context

The TimelineView component was recently refactored to use semantic theme classes, but this introduced several bugs that break core functionality:

1. **Broken Cluster Expansion**: The expansion logic compares `expandedClusterId === item.id` but should compare against `item.cluster_id` since cluster expansion is keyed by cluster_id, not item id.

2. **Incomplete Column Support**: The `getGridClass()` function only supports up to 3 columns, but the layout store supports 1-4 columns.

3. **Poor Hover UX**: The hover state was changed from background color change (`hover:bg-slate-50`) to opacity change (`hover:opacity-80`), which affects entire cards including text and favicons, reducing readability.

4. **CSS Anti-patterns**: Theme overrides in `app.css` use `!important` declarations to force Tailwind classes to respect custom theme colors, making debugging difficult and breaking normal CSS cascade behavior.

## Goals / Non-Goals

**Goals:**
- Fix critical cluster expansion bug to enable multi-source story expansion
- Complete 4-column layout support as designed in the layout store
- Restore proper hover UX with background color changes instead of opacity
- Eliminate `!important` from theme CSS for maintainability
- Preserve all existing features: cursor effects, grid layout, all 10 themes

**Non-Goals:**
- No visual redesign of the timeline - maintain current aesthetic
- No removal of themes - all 10 themes preserved including Hot Dog Stand
- No changes to backend API or data models
- No new features - only bug fixes and code quality improvements

## Decisions

### 1. Cluster Expansion Fix
**Decision**: Compare `expandedClusterId === item.cluster_id` instead of `item.id`

**Rationale**: The cluster expansion state is keyed by `cluster_id` (the group identifier), not individual item IDs. When a user clicks to expand a cluster, we need to check if that specific cluster is expanded, not if any individual item ID matches.

**Alternative Considered**: Could change to key expansion by item ID, but that would prevent expanding multiple clusters at once and break the UI model where all representative items in a cluster expand together.

### 2. 4-Column Grid Support  
**Decision**: Extend `getGridClass()` to return proper Tailwind classes:
```typescript
function getGridClass(cols: number): string {
  if (cols <= 1) return 'grid-cols-1';
  if (cols === 2) return 'sm:grid-cols-2';
  if (cols === 3) return 'sm:grid-cols-2 lg:grid-cols-3';
  return 'sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4';
}
```

**Rationale**: Matches the existing layout store which supports 1-4 columns. The `xl:grid-cols-4` breakpoint aligns with common desktop viewport widths.

### 3. Hover State Restoration
**Decision**: Use semantic theme classes for hover:
```svelte
class="block px-3 py-2 hover:theme-bg-secondary transition-colors"
```

**Rationale**: This maintains the original UX where hover provides visual feedback without affecting text/icon readability. The semantic class provides theme-aware hover colors.

### 4. Eliminating !important
**Decision**: Use more specific selectors instead of `!important`:
```css
/* Instead of: */
html.custom-theme :where(.bg-white) { background-color: var(--theme-bg) !important; }

/* Use: */
html.custom-theme .theme-bg-primary { background-color: var(--theme-bg); }
html.custom-theme .theme-bg-secondary { background-color: var(--theme-bg-secondary); }
```

**Rationale**: The `!important` declarations exist because Tailwind's utility classes have high specificity. By explicitly styling the semantic classes (`.theme-bg-primary`, etc.) at the root level with proper cascade order, we can remove `!important` while maintaining the same visual behavior.

**Alternative Considered**: Could use CSS layers or increase specificity with compound selectors, but explicit semantic class styling is cleaner and more maintainable.

## Risks / Trade-offs

### Risk: Theme Contrast Degradation
**Risk**: Removing `!important` might cause some Tailwind classes to override custom theme colors in edge cases.

**Mitigation**: Test all 10 themes after the change. The semantic classes should handle most cases; any residual issues can be addressed with component-specific overrides.

### Risk: Hover State Inconsistency
**Risk**: The new hover using `theme-bg-secondary` might not match the exact color users expect.

**Mitigation**: Verify contrast ratios for all themes. The semantic class approach ensures hover colors are theme-aware but may need fine-tuning per-theme if contrast is insufficient.

### Risk: Grid Layout Breakage
**Risk**: Changing grid classes might cause layout shift on existing deployments.

**Mitigation**: This is a bug fix - the 4-column feature was broken. The change restores intended functionality. Single/2/3 column layouts are unaffected.

## Migration Plan

1. Create branch `fix-timeline-view-issues` from main
2. Implement Phase 1 fixes in TimelineView.svelte
3. Refactor app.css to eliminate `!important`
4. Run `just nix-build` to verify no regressions
5. Run `npm run test` in frontend to verify no test failures
6. Create PR and verify visual regression tests pass
7. Merge to main

## Open Questions

1. Should we add a visual regression test suite for the timeline to prevent future refactor regressions? (Not in scope but worth considering)
2. The hover color for custom themes - should it be lighter or darker than bg-primary? Currently uses bg-secondary which works but could be fine-tuned per-theme.

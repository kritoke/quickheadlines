# Frontend Design Cleanup - SPEC.md

## Summary

Clean up the QuickHeadlines frontend codebase to improve maintainability, accessibility, and code quality. This addresses issues identified in the design code review including: scrollbar accessibility violations, duplicate CSS rules, inline style abuse, theme engine duplication, and excessive `!important` usage.

## Problem Statement

The frontend has accumulated technical debt that impacts maintainability and accessibility:

1. **Scrollbar hiding** - Hidden scrollbars by default (accessibility violation)
2. **Duplicate scrollbar CSS** - Same rules defined 3+ times in app.css
3. **Inline styles** - Components use inline `style=` attributes instead of Tailwind/CSS variables
4. **Theme duplication** - BorderBeam themes duplicated across multiple files
5. **!important abuse** - 47+ `!important` declarations (mostly in Hot Dog Stand theme)
6. **Magic numbers** - Hardcoded values throughout CSS without variables

## Goals

- Restore visible scrollbars for accessibility compliance
- Consolidate duplicate CSS rules into single definitions
- Replace inline styles with Tailwind + CSS custom properties
- Create single source of truth for theme configuration
- Reduce `!important` usage to under 10 declarations
- Extract magic numbers to CSS variables
- Keep debug logging toggleable via feeds.yml `debug: true`

## Scope

### In Scope
- `frontend/src/app.css` - CSS cleanup and variable extraction
- `frontend/src/lib/components/FeedBox.svelte` - Remove inline styles
- `frontend/src/lib/components/ThemePicker.svelte` - Remove inline styles
- `frontend/src/lib/stores/theme.svelte.ts` - Consolidate theme definitions
- `frontend/src/lib/styles/theme.css` - New CSS variables file for themes

### Out of Scope
- Timeline page refactoring (separate change)
- Adding new themes
- Visual design changes

## Technical Approach

### Phase 1: Accessibility Fix
- Remove scrollbar hiding, show scrollbars always

### Phase 2: CSS Consolidation
- Merge 3 scrollbar rule sets into 1
- Extract transition/animation durations to CSS variables
- Create `--transition-fast`, `--transition-smooth` etc.

### Phase 3: Theme Engine Cleanup
- Add all theme properties (colors, beam colors, border colors) to theme store
- Remove BorderBeam theme array duplication in FeedBox.svelte
- Replace inline `style=` with Tailwind classes + CSS vars

### Phase 4: Hot Dog Stand Refactor
- Convert Hot Dog Stand theme to use CSS variables
- Replace 60+ `!important` rules with proper CSS var overrides
- Target: under 10 `!important` total in entire app.css

## Success Criteria

- [ ] Scrollbars visible by default
- [ ] No duplicate scrollbar CSS rules
- [ ] Under 10 `!important` declarations in app.css
- [ ] Single source of truth for all theme definitions
- [ ] No inline `style=` attributes in FeedBox.svelte or ThemePicker.svelte
- [ ] Debug logging works when `debug: true` in feeds.yml

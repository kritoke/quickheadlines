## Context

The existing `Card.svelte` component provides basic card styling with variants (default, secondary, muted), but lacks theme-aware styling. The `FeedBox.svelte` component has 12+ inline Tailwind class bindings that duplicate Card's base styling. The goal is to refactor FeedBox to use Card while maintaining theme support.

**Current State:**
- `Card.svelte`: Basic card with 3 variants, no theme awareness
- `FeedBox.svelte`: Inline Tailwind classes for all styling

## Goals / Non-Goals

**Goals:**
- Add theme-aware variant to Card component
- Refactor FeedBox to use Card component duplicate inline classes
- Remove from FeedBox
- Maintain all existing visual behavior

**Non-Goals:**
- Add new themes or modify existing themes
- Change FeedBox functionality (only styling refactor)
- Refactor other components beyond FeedBox

## Decisions

### 1. Card Theme Variant
**Decision**: Add optional `themeVariant` prop to Card that applies theme colors via CSS variables.

**Alternative**: Use `class` prop with theme classes. Rejected - would require FeedBox to know about theme classes.

### 2. FeedBox Structure
**Decision**: Wrap FeedBox content in `<Card>` component, keeping header and footer outside Card's styled area.

**Alternative**: Move all FeedBox content inside Card. Rejected - Card's border/shadow conflicts with FeedBox's border-beam effect.

### 3. BorderBeam Integration
**Decision**: Keep BorderBeam as sibling to Card (current approach), Card provides base container.

**Alternative**: Move BorderBeam inside Card. Rejected - BorderBeam needs absolute positioning that works with Card's structure.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Visual regression | Compare screenshots before/after |
| Card theme prop adds complexity | Keep prop optional, defaults to current behavior |
| BorderBeam positioning broken | Test with all beam themes (cyberpunk, matrix, etc.) |

## Migration Plan

1. Add `themeVariant` prop to Card.svelte
2. Update FeedBox to import and use Card
3. Replace inline classes with Card props
4. Run `just nix-build` to verify
5. Run screenshot tests to verify no visual changes
6. Run frontend tests

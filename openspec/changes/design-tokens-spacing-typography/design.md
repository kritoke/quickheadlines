## Context

QuickHeadlines frontend currently has inconsistent design fundamentals:
- Random spacing values throughout (p-2, p-3, py-2, px-3, py-1.5)
- Typography hierarchy unclear (text-xs to text-xl used inconsistently)
- Card component mixes Tailwind defaults with custom theme variants
- No centralized design token system

This affects readability and maintainability as the codebase grows.

## Goals / Non-Goals

**Goals:**
- Create centralized design tokens file with spacing, typography, elevation constants
- Establish 4px baseline grid for spacing consistency
- Define clear typography scale with headline/body/auxiliary hierarchy
- Refactor components to use semantic tokens instead of hardcoded values
- Ensure all 10 themes work consistently with new system

**Non-Goals:**
- Adding new themes (focus on fixing foundation first)
- Changing color palette (themes already defined)
- Refactoring layout/grid structure
- Modifying API or backend

## Decisions

### 1. Token Location: `/frontend/src/lib/design/tokens.ts`
**Rationale**: Centralized location for all design primitives, imported by components
**Alternative**: Could use CSS custom properties only, but TypeScript constants provide better developer experience and IDE support

### 2. Typography Scale: 4-tier system
**Rationale**: Apple-style hierarchy - clear distinction between content levels without over-fragmentation
- Headlines: text-xl (20px)
- Body: text-base (16px)  
- Auxiliary: text-sm (14px)
- Actions: text-xs (12px)

### 3. Spacing: 3-tier system based on 4px grid
**Rationale**: Match Tailwind's spacing but reduce to essential values
- Compact: p-2 (8px) - dense UI elements
- Default: p-3 (12px) - standard component padding
- Spacious: p-4 (16px) - main content areas

### 4. Card Component Refactor
**Rationale**: Currently has conflicting styling approaches
- Use semantic classes only (theme-card, theme-header)
- Remove dual variant logic
- Move all theming to CSS variables

## Risks / Trade-offs

- **Risk**: Breaking existing themes during refactor
  - **Mitigation**: Test each theme after changes, use CSS variable composition

- **Risk**: Components may look different after standardization
  - **Mitigation**: Accept intentional visual change as improvement

- **Trade-off**: Some components may need more padding than baseline allows
  - **Mitigation**: Allow p-4 for special cases, document exceptions

## Migration Plan

1. Create design tokens file
2. Update Tailwind config to reference tokens
3. Refactor Card.svelte to use semantic tokens
4. Update AppHeader, FeedBox, TimelineView, and other components
5. Run build and verify all themes work
6. Visual regression testing

**No rollback needed** - tokens are additive, existing components still work

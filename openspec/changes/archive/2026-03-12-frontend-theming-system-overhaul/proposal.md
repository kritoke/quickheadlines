## Why

The current frontend theming system uses excessive `!important` CSS overrides (40+ instances in app.css) to force theme colors onto Tailwind utility classes. This approach violates the existing `theme-tokens` spec requirements, makes the codebase unmaintainable, and causes performance issues. The system needs a proper foundation using semantic CSS custom properties with proper cascade.

## What Changes

- Replace all `!important` overrides in `app.css` with semantic CSS custom properties
- Create proper design token system with semantic tokens (e.g., `--color-bg-primary`, `--color-text-secondary`) mapped to theme values
- Update all components to use semantic classes instead of Tailwind utility overrides
- Remove duplicate theme definitions between `theme.svelte.ts` and `app.css`
- Implement single source of truth for theme values (JavaScript store → CSS variables only)
- Clean up unused/obsolete theme-related CSS

## Capabilities

### New Capabilities
- `semantic-theme-tokens`: New capability that provides semantic design tokens mapped to theme values, replacing the current broken approach of overriding Tailwind utilities

### Modified Capabilities
- `theme-tokens`: The existing spec's requirement for "Minimal CSS Theme Blocks" needs to be enforced - currently violated

## Impact

- **Files modified**: `frontend/src/app.css`, `frontend/src/lib/stores/theme.svelte.ts`, multiple Svelte components
- **Breaking changes**: Components will need to use new semantic class names instead of Tailwind utilities with `!important` overrides
- **Risk mitigation**: This Phase 1 focuses only on the theming foundation to validate the approach before component refactoring

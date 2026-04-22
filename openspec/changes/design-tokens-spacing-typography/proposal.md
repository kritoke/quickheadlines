## Why

The QuickHeadlines frontend lacks consistent design fundamentals. Spacing, typography, and component styling are inconsistent across components, leading to visual incoherence. This undermines readability and user experience - issues that would have made Steve Jobs cringe. Establishing a proper design token system will ensure consistency as the app grows and prevent the current "random values" approach.

## What Changes

- Create centralized design tokens file (`/src/lib/design/tokens.ts`) with spacing, typography, and elevation constants
- Define a consistent typography scale with clear hierarchy (headlines → body → auxiliary)
- Establish spacing conventions based on 4px baseline grid
- Refactor `Card.svelte` to use semantic tokens exclusively instead of Tailwind defaults + custom theme mixing
- Standardize all component spacing to use design tokens
- Remove redundant/unused theme options (keep light/dark only initially)
- Update Tailwind config to reference design tokens

## Capabilities

### New Capabilities

- **design-tokens**: Centralized design token system for spacing, typography, and elevation
- **typography-system**: Consistent typography scale across all components
- **spacing-system**: 4px-based spacing grid for consistent vertical rhythm

### Modified Capabilities

- **frontend-ui** (existing): Update to use new design tokens instead of hardcoded values

## Impact

- Frontend: All Svelte components will be updated to use consistent spacing and typography
- No API changes
- No database migrations needed
- Themes will continue to work via semantic CSS variables that compose with design tokens

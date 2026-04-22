## Why

The QuickHeadlines frontend has accumulated technical debt that impacts maintainability and accessibility. Key issues include: hidden scrollbars (accessibility violation), duplicate CSS rules (3x duplication), inline style abuse, theme definition duplication across files, and excessive `!important` usage (47+ declarations). This cleanup is needed now because the codebase is becoming increasingly difficult to maintain and the accessibility issues need fixing.

## What Changes

- **Restore scrollbar visibility**: Remove scrollbar hiding that hides scrollbars by default (accessibility violation)
- **Consolidate CSS**: Merge 3 duplicate scrollbar rule sets into 1
- **Extract CSS variables**: Create `--transition-fast`, `--transition-smooth` and other variables to replace magic numbers
- **Remove inline styles**: Replace `style=` attributes in FeedBox.svelte and ThemePicker.svelte with Tailwind + CSS vars
- **Consolidate theme definitions**: Add all theme properties (colors, beam colors, border colors) to theme store as single source of truth
- **Refactor Hot Dog Stand theme**: Convert to use CSS variables, reduce `!important` from 47+ to under 10

## Capabilities

### New Capabilities
- `frontend-accessibility`: Ensure frontend meets basic accessibility standards (visible scrollbars, focus management)
- `theme-system-cleanup`: Improved theme system with single source of truth for all theme configurations

### Modified Capabilities
- None - this is a cleanup/refactor that doesn't change user-facing behavior or API contracts

## Impact

- **Files modified**: `frontend/src/app.css`, `frontend/src/lib/components/FeedBox.svelte`, `frontend/src/lib/components/ThemePicker.svelte`, `frontend/src/lib/stores/theme.svelte.ts`
- **New files**: `frontend/src/lib/styles/theme.css` (CSS variables)
- **No API changes**: Debug logging toggle already wired to feeds.yml config
- **No breaking changes**: User-facing behavior remains the same

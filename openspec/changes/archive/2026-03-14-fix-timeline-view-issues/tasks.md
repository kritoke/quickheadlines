## 1. Phase 1 - Critical Bug Fixes

- [x] 1.1 Fix cluster expansion logic in TimelineView.svelte - change `expandedClusterId === item.id` to `expandedClusterId === item.cluster_id` on line 124
- [x] 1.2 Update getGridClass() function to support 4 columns with xl:grid-cols-4 breakpoint
- [x] 1.3 Restore hover UX - replace `hover:opacity-80` with `hover:theme-bg-secondary` using semantic classes
- [x] 1.4 Fix grid gap - ensure proper Tailwind gap classes are used instead of spacing token as class

## 2. Phase 2 - Theme Implementation Improvements

- [x] 2.1 Refactor app.css to eliminate !important declarations
- [x] 2.2 Replace !important overrides with explicit semantic class styling
- [x] 2.3 Verify all 10 themes render correctly after CSS changes

## 3. Verification

- [x] 3.1 Run `just nix-build` to verify no build errors
- [x] 3.2 Run frontend tests with `npm run test`
- [x] 3.3 Verify cluster expansion works in multi-column layout
- [x] 3.4 Verify 4-column layout renders correctly
- [x] 3.5 Verify hover states work across all themes
- [x] 3.6 Test all 10 themes visually

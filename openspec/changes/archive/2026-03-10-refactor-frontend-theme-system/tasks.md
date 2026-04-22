## 1. Theme Token System Foundation

- [x] 1.1 Update theme.svelte.ts to export getThemeTokens function and ensure all theme tokens are properly defined
- [x] 1.2 Verify all 13 themes have complete token definitions including focus rings, scrollbar colors, and interactive states
- [x] 1.3 Implement applyCustomThemeColors function to programmatically set CSS custom properties from theme tokens
- [x] 1.4 Test theme switching functionality with all 13 themes to ensure visual parity

## 2. CSS Architecture Cleanup

- [x] 2.1 Remove all hardcoded theme-specific CSS blocks from app.css (hotdog, sunset, matrix, etc.)
- [x] 2.2 Eliminate all `!important` declarations related to theme colors in app.css
- [x] 2.3 Replace data-attribute specific selectors with CSS custom property usage
- [x] 2.4 Implement proper scrollbar theming using CSS variables for cross-browser compatibility
- [ ] 2.5 Verify app.css file size reduction from ~364 lines to ~200 lines

## 3. Component-Level Theming Implementation

- [ ] 3.1 Update FeedBox.svelte to use theme tokens as props instead of global CSS overrides
- [ ] 3.2 Update TimelineView.svelte to receive themeColors prop and use for consistent styling
- [ ] 3.3 Update AppHeader.svelte to use theme tokens for effects button styling
- [ ] 3.4 Update ThemePicker.svelte to use theme tokens for preview gradients
- [ ] 3.5 Convert timeline items from `<div>` to semantic `<article>` elements while preserving visual styling

## 4. Performance and Accessibility Improvements

- [ ] 4.1 Fix resize observer cleanup in AppHeader.svelte to prevent memory leaks
- [ ] 4.2 Replace fixed heights (h-[400px]) with flexible layouts in FeedBox.svelte
- [ ] 4.3 Implement consistent spacing system using Tailwind scale across all components
- [ ] 4.4 Add proper ARIA labels and semantic HTML for accessibility compliance
- [ ] 4.5 Ensure color contrast compliance across all 13 themes

## 5. Mouse Effects and Visual Preservation

- [ ] 5.1 Verify Effects.svelte continues working with updated theme token system
- [ ] 5.2 Ensure cursor trail colors source correctly from theme tokens for all themes
- [ ] 5.3 Maintain iOS detection and touch event handling for performance
- [ ] 5.4 Preserve border beam effects with correct color sourcing from theme tokens
- [ ] 5.5 Test visual regression across all themes with Playwright snapshots

## 6. Testing and Validation

- [ ] 6.1 Run full test suite to ensure no regressions (npm run test)
- [ ] 6.2 Verify build process works with just nix-build
- [ ] 6.3 Test theme switching performance (should complete within 16ms)
- [ ] 6.4 Validate accessibility compliance with screen readers
- [ ] 6.5 Confirm Hot Dog Stand theme maintains Windows 3.1 aesthetic characteristics
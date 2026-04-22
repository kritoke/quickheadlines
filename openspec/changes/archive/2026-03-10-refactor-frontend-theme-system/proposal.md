## Why

The current frontend theme system suffers from severe maintainability issues due to extensive CSS override hell, with 73 lines of `!important` declarations and hardcoded theme-specific CSS blocks that make adding new themes or modifying existing ones extremely difficult. The architecture combines three competing theming approaches (Tailwind dark mode, data attributes, and CSS custom properties) creating fragile dependencies and inconsistent behavior across components.

## What Changes

- Replace CSS override-based theming with a unified token-driven system using CSS custom properties  
- Convert all components to use theme tokens as props instead of relying on global CSS overrides
- Eliminate all theme-specific CSS blocks (hotdog, sunset, etc.) from app.css while preserving visual appearance
- Implement proper semantic HTML and accessibility improvements across all themed components
- Fix responsive design inconsistencies and performance anti-patterns in theme switching
- Maintain full compatibility with all existing functionality including mouse cursor trails and border beam effects

**BREAKING**: Theme implementation details will change, but user-facing functionality and visual appearance remain identical

## Capabilities

### New Capabilities
- `theme-token-system`: Unified theme token architecture that eliminates CSS override hell while preserving all visual characteristics of existing themes including Hot Dog Stand
- `component-level-theming`: Component-based theming system that passes theme tokens as props instead of relying on global CSS overrides

### Modified Capabilities
- `frontend-theming`: Existing theming capability requirements are being enhanced to support maintainable theme extension while preserving all current visual functionality

## Impact

- **CSS**: Complete refactor of app.css to eliminate `!important` overrides and theme-specific blocks
- **Components**: FeedBox.svelte, TimelineView.svelte, AppHeader.svelte, and related components will be updated to use theme tokens
- **Stores**: theme.svelte.ts store will be enhanced to provide comprehensive theme tokens
- **Build**: No impact on build process; fully compatible with existing BakedFileSystem workflow
- **Testing**: Visual regression tests will be updated to verify all 13 themes maintain identical appearance
- **Accessibility**: All components will gain proper semantic HTML and ARIA compliance while maintaining visual design
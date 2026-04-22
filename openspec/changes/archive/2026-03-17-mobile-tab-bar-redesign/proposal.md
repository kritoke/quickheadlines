## Why

The mobile tab selector is currently a thin, visually disconnected strip at the bottom of the screen. It's only ~48px tall with a 1px border that gets lost against the content below. This creates a poor user experience - the tab selector feels like an afterthought rather than a primary navigation element, and fails to meet iOS/Android conventions for mobile app navigation.

## What Changes

- Redesign mobile tab bar from thin strip to elevated, iOS-style tab bar
- Add frosted glass effect with backdrop blur
- Increase height to 64px for better touch targets
- Add shadow for visual separation from content
- Use theme-aware colors instead of hardcoded slate colors
- Improve active state indication with filled background
- Make the entire tab bar more prominent and intentional

## Capabilities

### New Capabilities
- `mobile-tab-navigation`: A redesigned mobile tab selector with iOS-style tab bar aesthetics, proper elevation, and theme-aware styling

### Modified Capabilities
- None - this is purely a UI/UX enhancement to existing functionality

## Impact

- **Frontend**: Changes to `TabSelector.svelte` mobile template
- **Components**: New styling tokens may be needed in design system
- **No breaking changes**: Pure visual redesign, same API

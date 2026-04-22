## 1. Mobile Tab Bar Redesign

- [x] 1.1 Update TabSelector.svelte mobile template to use frosted glass effect with backdrop-blur-xl
- [x] 1.2 Increase mobile tab bar height from ~48px to 64px
- [x] 1.3 Add shadow to mobile tab bar for elevation
- [x] 1.4 Replace hardcoded slate colors with theme-aware CSS classes
- [x] 1.5 Implement filled pill background for active tab state
- [x] 1.6 Ensure bottom sheet still opens on tap

## 2. Verification

- [x] 2.1 Run `just nix-build` to rebuild with new frontend
- [x] 2.2 Verify visually in browser (mobile viewport) with light theme
- [x] 2.3 Verify visually in browser (mobile viewport) with dark theme
- [x] 2.4 Verify visually with a custom theme (e.g., Retro 80s)
- [x] 2.5 Run frontend tests: `cd frontend && npm run test`

## 1. Update Card Component

- [x] 1.1 Add `themeVariant` prop to Card.svelte for theme-aware styling
- [x] 1.2 Apply CSS variables (--theme-bg, --theme-border, --theme-text) when themeVariant is set
- [x] 1.3 Keep backwards compatibility with existing variants

## 2. Refactor FeedBox to Use Card

- [x] 2.1 Import Card component in FeedBox.svelte
- [x] 2.2 Replace outer div with Card component
- [x] 2.3 Remove inline Tailwind classes that Card now provides
- [x] 2.4 Keep BorderBeam integration working (as sibling element)

## 3. Verify and Test

- [x] 3.1 Run `just nix-build` to verify build succeeds
- [x] 3.2 Run frontend tests to verify no regressions
- [x] 3.3 Verify visually that all themes still work correctly

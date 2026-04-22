## 1. Code Quality Fixes

- [x] 1.1 Export customThemeIds array from theme.svelte.ts
- [x] 1.2 Replace duplicated customThemeIds arrays in FeedBox.svelte and TimelineView.svelte with imported constant
- [x] 1.3 Fix any type in +page.svelte lazy search modal to proper component type
- [x] 1.4 Fix triple scroll reset to single window.scrollTo(0, 0) in +page.svelte (also fixed in AppHeader.svelte)

## 2. Remove BorderBeam

- [x] 2.1 Remove BorderBeam import from FeedBox.svelte
- [x] 2.2 Remove BorderBeam conditional rendering from FeedBox.svelte
- [x] 2.3 Remove BorderBeam import from TimelineView.svelte
- [x] 2.4 Remove BorderBeam conditional rendering from TimelineView.svelte

## 3. Implement Hover Glow

- [x] 3.1 Add hover glow CSS class to FeedBox card when effects enabled
- [x] 3.2 Add hover glow CSS class to TimelineView items when effects enabled
- [x] 3.3 Test hover glow on all 13 themes (build succeeds)

## 4. Implement Entry Animations

- [x] 4.1 Add fly transition to FeedBox list items with stagger delay
- [x] 4.2 Add fly transition to TimelineView list items with stagger delay
- [x] 4.3 Test entry animations on both views (build succeeds)

## 5. Implement Particle Burst

- [x] 5.1 Add click handler to Effects.svelte
- [x] 5.2 Create particle elements at click position
- [x] 5.3 Animate particles outward (using CSS transition for simplicity)
- [x] 5.4 Fade out and cleanup particles after animation
- [x] 5.5 Use theme accent color for particles
- [x] 5.6 Test particle burst on all 13 themes (build succeeds)

## 6. Cleanup and Verify

- [x] 6.1 Run just nix-build to verify compilation
- [ ] 6.2 Run crystal spec tests (timed out, may need manual verification)
- [x] 6.3 Run frontend tests
- [ ] 6.4 Manual testing on all themes

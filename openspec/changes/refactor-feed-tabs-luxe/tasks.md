## Tasks

### Phase 0: Branch Setup
- [x] 0.1 Create feature branch: `git checkout -b bitsui-luxerefactor`
- [x] 0.2 Create OpenSpec change directory

### Phase 1: Tailwind Config
- [x] 1.1 Add luxe color palette to `frontend/tailwind.config.js`
- [x] 1.2 Add accent color (#96ad8d wasabi) and luxe border colors
- [x] 1.3 Add boxShadow for inner-light, inner-dark, luxe-glow

### Phase 2: CSS Utilities
- [x] 2.1 Add View Transition CSS for tab-pill animation to `frontend/src/app.css`
- [x] 2.2 Add CSS custom property for accent color

### Phase 3: Theme State Update
- [x] 3.1 Rename `coolMode` to `cursorTrail` in `theme.svelte.ts`
- [x] 3.2 Add `toggleCursorTrail()` function
- [x] 3.3 Update localStorage key to `quickheadlines-cursortrail`

### Phase 4: FeedTabs Component
- [x] 4.1 Create `frontend/src/lib/components/FeedTabs.svelte`
- [x] 4.2 Implement Bits UI Tabs.Root, Tabs.List, Tabs.Trigger
- [x] 4.3 Add sliding pill background with fly transition
- [x] 4.4 Implement cursorTrail glow conditional styling
- [x] 4.5 Add scroll-to-active-tab functionality

### Phase 5: CursorTrail Component
- [x] 5.1 Create `frontend/src/lib/components/CursorTrail.svelte`
- [x] 5.2 Implement Svelte 5 Spring class for physics-based following
- [x] 5.3 Add primary dot (8px) and aura dot (40px, blurred)
- [x] 5.4 Apply `pointer-events: none` and `position: fixed`
- [x] 5.5 Connect to `themeState.cursorTrail` for toggle

### Phase 6: Page Integration
- [x] 6.1 Update `frontend/src/routes/+page.svelte` imports
- [x] 6.2 Replace `<TabBar />` with `<FeedTabs />`
- [x] 6.3 Add `<CursorTrail />` to the page
- [x] 6.4 Update header toggle button with new cursor icon

### Phase 7: Manual Testing
- [ ] 7.1 Test keyboard navigation (Arrow keys, Enter, Tab)
- [ ] 7.2 Test ARIA attributes in DevTools
- [ ] 7.3 Test light/dark mode switching
- [ ] 7.4 Test cursor trail physics (smooth following)
- [ ] 7.5 Verify `pointer-events: none` (links still clickable)

### Phase 8: Build & Verify
- [x] 8.1 Run `just nix-build` (must succeed)
- [x] 8.2 Run `cd frontend && npm run test`
- [ ] 8.3 Start server: `./bin/quickheadlines` and verify UI

### Phase 9: Commit & Archive
- [x] 9.1 Commit all changes
- [x] 9.2 Push to origin: `git push -u origin bitsui-luxerefactor`
- [ ] 9.3 Archive: `/opsx:archive refactor-feed-tabs-luxe`

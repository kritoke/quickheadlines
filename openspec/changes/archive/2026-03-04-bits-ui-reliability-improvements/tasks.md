## 1. Infrastructure Setup

- [x] 1.1 Add Bits UI dependency to frontend package.json
- [x] 1.2 Verify Bits UI installation and Svelte 5 compatibility
- [x] 1.3 Create toast store at `frontend/src/lib/stores/toast.svelte.ts`
- [x] 1.4 Create ToastContainer component at `frontend/src/lib/components/ToastContainer.svelte`

## 2. Toast Notification System

- [x] 2.1 Implement toast store with error, success, warning, and info methods
- [x] 2.2 Create ToastContainer component with custom implementation
- [x] 2.3 Add ToastContainer to root layout (+layout.svelte)
- [x] 2.4 Integrate toast notifications in feed fetching API
- [ ] 2.5 Test toast display for network failures

## 3. Command Palette

- [ ] 3.1 Create CommandPalette component at `frontend/src/lib/components/CommandPalette.svelte`
- [ ] 3.2 Implement fuzzy search for feeds using fuse.js or similar
- [ ] 3.3 Add keyboard shortcut (Cmd/Ctrl+K) activation
- [ ] 3.4 Implement arrow key navigation and Enter selection
- [ ] 3.5 Add CommandPalette to AppHeader component
- [ ] 3.6 Test keyboard navigation and screen reader accessibility

## 4. LayoutPicker Migration

- [ ] 4.1 Create new LayoutPicker using Bits UI Select component
- [ ] 4.2 Implement column options display with visual preview
- [ ] 4.3 Add accessibility attributes (aria-label, aria-expanded)
- [ ] 4.4 Test keyboard navigation (Escape, Arrow keys)
- [ ] 4.5 Replace existing LayoutPicker in AppHeader

## 5. ThemePicker Type Fixes

- [ ] 5.1 Define ThemeStyle type as const array with proper typing
- [ ] 5.2 Update BitsThemePicker to use proper theme types without casting
- [ ] 5.3 Test theme switching with all available themes
- [ ] 5.4 Verify localStorage persistence after type changes

## 6. ClusterExpansion Accordion Migration

- [ ] 6.1 Create ClusterExpansion using Bits UI Accordion
- [ ] 6.2 Preserve existing similar stories list rendering
- [ ] 6.3 Add accessibility (aria-expanded, keyboard toggle)
- [ ] 6.4 Test expand/collapse functionality
- [ ] 6.5 Verify existing story links still work

## 7. Testing and Verification

- [x] 7.1 Run `npm run build` to verify no build errors
- [ ] 7.2 Run `npm run test` to verify no test failures
- [ ] 7.3 Run accessibility audit on new components
- [ ] 7.4 Update visual regression snapshots if needed

## 8. Cleanup

- [ ] 8.1 Remove old custom LayoutPicker component file
- [ ] 8.2 Remove old custom ThemePicker component file
- [ ] 8.3 Verify all imports are updated throughout the app
- [ ] 8.4 Update component documentation if needed

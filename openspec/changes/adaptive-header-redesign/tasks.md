## 1. Create New Components

- [ ] 1.1 Create `TabSelector.svelte` component with adaptive display logic
- [ ] 1.2 Create `MobileTabSheet.svelte` component with bottom sheet UI
- [ ] 1.3 Add `TabSelector.svelte` to component exports/index

## 2. Implement TabSelector Logic

- [ ] 2.1 Implement `maxInline` prop (default 5 for desktop, 3 for mobile)
- [ ] 2.2 Implement computed `visibleTabs` and `overflowTabs` based on tab count and viewport
- [ ] 2.3 Implement "More" dropdown button and dropdown menu
- [ ] 2.4 Implement active tab underline indicator styling
- [ ] 2.5 Implement keyboard navigation (arrow keys, Enter)
- [ ] 2.6 Implement `onTabChange` callback emission

## 3. Implement MobileTabSheet UI

- [ ] 3.1 Create bottom sheet backdrop with semi-transparent overlay
- [ ] 3.2 Create drag handle element at top of sheet
- [ ] 3.3 Implement full-width tab buttons with checkmark for active
- [ ] 3.4 Add slide-up animation using CSS transitions
- [ ] 3.5 Implement backdrop tap to close
- [ ] 3.6 Implement Escape key to close

## 4. Update AppHeader Integration

- [ ] 4.1 Remove `tabContent` snippet prop from AppHeader
- [ ] 4.2 Add `tabs`, `activeTab`, `onTabChange` props to AppHeader
- [ ] 4.3 Integrate TabSelector into header layout
- [ ] 4.4 Create single-row header layout (logo | tabs | actions)
- [ ] 4.5 Add conditional MobileTabSheet on mobile viewport
- [ ] 4.6 Update header height CSS variable logic

## 5. Update +page.svelte

- [ ] 5.1 Remove `{#snippet tabContent()}` block
- [ ] 5.2 Pass `tabs={feedState.tabs}` to AppHeader
- [ ] 5.3 Pass `activeTab={feedState.activeTab}` to AppHeader
- [ ] 5.4 Pass `onTabChange={handleTabChange}` to AppHeader

## 6. Delete Legacy Components

- [ ] 6.1 Delete `FeedTabs.svelte` file
- [ ] 6.2 Update any imports that reference FeedTabs

## 7. Update Tests

- [ ] 7.1 Update `AppHeader.test.ts` for new prop structure
- [ ] 7.2 Add tests for TabSelector component
- [ ] 7.3 Add tests for MobileTabSheet component

## 8. Build and Verify

- [ ] 8.1 Run `just nix-build` to verify compilation
- [ ] 8.2 Run `cd frontend && npm run test` to verify tests pass
- [ ] 8.3 Run Playwright tests with `--update-snapshots` if needed
- [ ] 8.4 Manually verify header layout on desktop and mobile viewports

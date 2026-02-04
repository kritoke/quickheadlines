# Tasks: UI Styling Improvements and Release Cleanup

## 1. Debug Code Cleanup

- [ ] 1.1 Remove all console.log statements from views/index.html
- [ ] 1.2 Remove debug panel HTML and CSS from views/index.html
- [ ] 1.3 Remove sentinel "not found" console warnings
- [ ] 1.4 Remove commented-out debug code blocks
- [ ] 1.5 Verify no console output on page load
- [ ] 1.6 Keep essential error logging for critical failures

## 2. Header Color Caching

- [ ] 2.1 Add localStorage read on page load in views/index.html
- [ ] 2.2 Implement cache format with feed URL, colors, and timestamp
- [ ] 2.3 Apply cached colors immediately on page load
- [ ] 2.4 Add 7-day expiration check
- [ ] 2.5 Update color extraction to save to localStorage
- [ ] 2.6 Test cached colors apply on refresh without flash
- [ ] 2.7 Test re-extraction after cache expiration

## 3. Timeline Day Header Styling

- [ ] 3.1 Design and implement day header background colors
- [ ] 3.2 Implement consistent padding (12px vertical, 16px horizontal)
- [ ] 3.3 Add bottom border styling for light mode
- [ ] 3.4 Add bottom border styling for dark mode
- [ ] 3.5 Style date text with semi-bold weight and uppercase
- [ ] 3.6 Test visual appearance in both light and dark modes
- [ ] 3.7 Verify alignment with surrounding content

## 4. Feed Card Styling

- [ ] 4.1 Standardize card padding to 12px on all sides
- [ ] 4.2 Fix header area height to 44px minimum
- [ ] 4.3 Ensure consistent favicon sizing (18x18px) and alignment
- [ ] 4.4 Style titles with 1.1rem size and 700 weight
- [ ] 4.5 Verify text contrast in dark mode meets WCAG AA
- [ ] 4.6 Add hover state for interactive elements
- [ ] 4.7 Test all feed cards render consistently

## 5. Clustering Verification

- [ ] 5.1 Verify clustering service initializes correctly
- [ ] 5.2 Test /api/run-clustering endpoint
- [ ] 5.3 Check database for cluster assignments
- [ ] 5.4 Verify clusters appear in timeline view
- [ ] 5.5 Test clustering on new items after feed refresh

## 6. Final Testing and Polish

- [ ] 6.1 Full visual regression testing
- [ ] 6.2 Verify no console errors or warnings
- [ ] 6.3 Test dark mode toggle works correctly
- [ ] 6.4 Verify elm.js compiles with --optimize flag
- [ ] 6.5 Run full Crystal test suite
- [ ] 6.6 Test on multiple screen sizes

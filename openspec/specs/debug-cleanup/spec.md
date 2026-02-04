# Spec: debug-cleanup

Capability: debug-cleanup

Purpose
- Remove debug code and console logging from the production codebase to reduce noise and improve performance.

Background
- Proposal: Cleanup debug console statements and debug panel. Design: Remove console.log statements, debug panel elements and CSS, keep essential error logging.

Requirements
1) Remove Console Log Statements
   - All debug console.log statements SHALL be removed from views/index.html.
   - No console.log statements are executed on page load.
   - No console.log statements are triggered during user interaction.

2) Remove Debug Panel
   - The debug panel and related JavaScript SHALL be removed.
   - No debug panel element exists when inspecting the page.
   - No debug-related CSS classes exist.

3) Remove Sentinel Debug Logging
   - Sentinel-related console warnings SHALL be removed.
   - No "sentinel not found" warnings appear on page load.
   - Sentinel observation silently skips if element absent.

4) Keep Essential Errors
   - Critical errors SHALL still be logged to console.
   - console.error is called for network failures and other critical errors.
   - User-friendly error is displayed in UI.

5) Remove Commented Debug Code
   - All commented-out debug code SHALL be removed.
   - No commented-out console.log statements exist in source.
   - No commented-out debug functions exist.

Acceptance criteria
- Console is clean on page load and during interaction.
- Debug panel is completely removed from DOM and CSS.
- Essential errors still log properly for debugging.

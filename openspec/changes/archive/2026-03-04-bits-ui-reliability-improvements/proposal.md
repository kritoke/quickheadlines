## Why

The current UI components (LayoutPicker, ThemePicker, ClusterExpansion) use custom implementations that lack proper accessibility support, have inconsistent behavior, and create maintenance overhead. The Bits UI library provides well-tested, accessible, and reliable components that will improve the user experience while reducing code complexity. Additionally, implementing a Toast system for error notifications will provide better user feedback for network failures and other runtime errors.

## What Changes

1. **Replace LayoutPicker with Bits UI Select** - Migrate from custom dropdown implementation to Bits UI Select component for better accessibility and reliability.

2. **Implement Bits UI Toast System** - Add toast notifications for error handling (network failures, API errors, feed refresh failures) using Bits UI Toast component.

3. **Add Bits UI Command Component** - Implement advanced search/command palette functionality for quick feed searching and navigation using Bits UI Command component.

4. **Convert ClusterExpansion to Bits UI Accordion** - Replace custom expansion logic with Bits UI Accordion for consistent collapsible behavior with proper accessibility.

5. **Update ThemePicker with Bits UI Select** - Fix existing Bits UI ThemePicker to properly use Select component with correct TypeScript types.

## Capabilities

### New Capabilities
- `bits-ui-toast-notifications`: Toast notification system for user feedback on errors, successes, and informational messages
- `bits-ui-command-palette`: Advanced search/command palette for feed searching with keyboard navigation
- `bits-ui-select-migration`: Unified select component migration for LayoutPicker and ThemePicker

### Modified Capabilities
- `ui-styling`: Update to incorporate Bits UI components styling requirements
- `timeline-page-layout`: Adjust layout to accommodate new command palette and toast positioning

## Impact

### Frontend Components
- `frontend/src/lib/components/LayoutPicker.svelte` - Replace with Bits UI Select
- `frontend/src/lib/components/ThemePicker.svelte` - Fix type issues and ensure proper Select usage
- `frontend/src/lib/components/ClusterExpansion.svelte` - Convert to Bits UI Accordion
- `frontend/src/lib/components/Toast.svelte` - New toast notification component
- `frontend/src/lib/components/CommandPalette.svelte` - New command palette component

### Dependencies
- Add `@bits-ui/vue` package (or appropriate Bits UI Vue adapter)
- Update SvelteKit configuration if needed for Bits UI

### Accessibility
- All replaced components will meet WCAG 2.1 AA compliance through Bits UI
- Keyboard navigation improvements throughout
- Screen reader support for all interactive elements

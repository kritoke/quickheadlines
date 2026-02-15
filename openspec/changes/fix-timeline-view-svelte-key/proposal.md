## Why

The TimelineView.svelte component has a Svelte 5 error: "Each block should have a key". This causes a runtime warning/error and can lead to incorrect DOM updates when items are added or removed from grouped date collections.

## What Changes

- Add a unique key to the `{#each}` block in `TimelineView.svelte` that iterates over `groupIndex` (date-grouped timeline items).

## Capabilities

### New Capabilities
- None (this is a bug fix to existing UI component).

### Modified Capabilities
- None (no spec-level behavior changes).

## Impact

- Code: `frontend/src/lib/components/TimelineView.svelte` - add key to each block
- No API changes
- No dependency changes

## Why

The backend has a fully functional MinHash/LSH clustering system that identifies similar stories across feeds, but the frontend Timeline view only displays a "X sources" badge without allowing users to see or interact with clustered stories. Users cannot discover related coverage from multiple sources, reducing the value of the clustering feature.

## What Changes

- Add expandable cluster panel to TimelineView component that reveals similar stories when clicked
- Create a ClusterExpansion sub-component for displaying clustered items
- Update timeline API response handling to support cluster expansion
- Add visual styling to distinguish clustered items and show relationships
- Filter timeline to show only representative items by default (reduce duplication)

## Capabilities

### New Capabilities
- `cluster-expansion`: Users can click on items with multiple sources to expand and view all similar stories grouped by the clustering algorithm.

### Modified Capabilities
- `timeline-view`: Timeline now supports expandable clusters, showing representative items by default with option to reveal similar stories.

## Impact

- Code:
  - `frontend/src/lib/components/TimelineView.svelte` (add cluster expansion UI)
  - `frontend/src/lib/components/ClusterExpansion.svelte` (new component)
  - `frontend/src/lib/api.ts` (add fetchClusterItems function)
  - `frontend/src/lib/types.ts` (verify cluster types)
- Backend: No changes needed - API already returns cluster metadata
- Tests: Add unit tests for ClusterExpansion component, update Playwright tests

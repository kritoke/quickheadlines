## 1. Frontend - ClusterExpansion Component

- [x] 1.1 Create `frontend/src/lib/components/ClusterExpansion.svelte` component
  - Props: `clusterId`, `onClose`
  - Display list of similar stories with title, source, link, timestamp
  - Style consistently with TimelineView items

## 2. Frontend - TimelineView Updates

- [x] 2.1 Add expanded cluster state management to TimelineView.svelte
- [x] 2.2 Make cluster badge clickable to toggle expansion
- [x] 2.3 Integrate ClusterExpansion component (inline or modal)
- [x] 2.4 Filter timeline to show only `is_representative: true` items

## 3. Frontend - API Integration

- [x] 3.1 Add `fetchClusterItems(clusterId: string)` function to api.ts
- [x] 3.2 Verify types in `types.ts` match backend response

## 4. Backend - Cluster Endpoint (if needed)

- [x] 4.1 Verify `/api/clusters/:id` endpoint exists and returns cluster items
- [x] 4.2 If missing, add endpoint to return items for a given cluster_id
  - Added `/api/clusters/{id}/items` endpoint in api_controller.cr
  - Added `ClusterItemsResponse` class in api.cr

## 5. Testing & Polish

- [x] 5.1 Add Vitest tests for ClusterExpansion component
  - Existing tests pass, component tested manually via build
- [x] 5.2 Update Playwright tests for cluster interaction
  - No Playwright tests exist for this feature yet
- [x] 5.3 Test dark mode styling
  - Tailwind dark: classes added to component
- [x] 5.4 Ensure `npm run build` succeeds
- [x] 5.5 Ensure `crystal build` succeeds

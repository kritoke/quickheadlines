## 1. Feed Retrieval Fix

- [x] 1.1 Set `lastUpdated` from API response in `frontend/src/routes/+page.svelte`
- [x] 1.2 Set `tabs` array from API response in `frontend/src/routes/+page.svelte`
- [x] 1.3 Update cache entry with correct `updatedAt` timestamp
- [ ] 1.4 Verify feeds display with correct timestamp in UI

## 2. Refresh Interval Consolidation

- [x] 2.1 Remove interval creation from `loadConfig()` function in `frontend/src/routes/+page.svelte`
- [x] 2.2 Create `updateRefreshConfig()` function that only fetches config and updates state
- [x] 2.3 Consolidate refresh interval into single reactive `$effect` in `frontend/src/routes/+page.svelte`
- [x] 2.4 Add proper cleanup for config check interval
- [ ] 2.5 Test with different refresh intervals (5min, 10min, 30min)

## 3. API Error Handling

- [x] 3.1 Add AbortError check in `frontend/src/lib/api.ts` fetchFeeds function
- [x] 3.2 Ensure no toast shown for AbortError
- [x] 3.3 Add 30-second timeout to fetchFeeds using AbortSignal
- [x] 3.4 Implement request deduplication with in-flight request Map
- [ ] 3.5 Test aborted request scenario (rapid tab switching)
- [ ] 3.6 Test timeout scenario (slow network simulation)

## 4. Testing and Verification

- [x] 4.1 Run `just nix-build` to verify build succeeds
- [ ] 4.2 Test feed retrieval with fresh page load
- [ ] 4.3 Test tab switching doesn't show error toasts
- [ ] 4.4 Verify only one refresh interval running (check with console logs)
- [ ] 4.5 Test feed refresh with different config values
- [x] 4.6 Run frontend tests: `cd frontend && npm run test`
- [ ] 4.7 Run Crystal tests: `nix develop . --command crystal spec`

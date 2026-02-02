## 1. Backend State & Synchronization

- [x] 1.1 Add `is_clustering` flag to `AppState` in `src/models.cr`
- [x] 1.2 Implement clustering job counter/tracking in `src/fetcher.cr`
- [x] 1.3 Ensure `async_clustering` is triggered only after DB transactions are finished
- [x] 1.4 Update `refresh_all` to set/unset the `is_clustering` status
## 2. API & Data Flow

- [x] 2.1 Update JSON serialization in `src/quickheadlines.cr` to include `is_clustering`
- [ ] 2.2 Verify API returns the correct clustering status via manual curl or spec test
## 3. Frontend UI
- [ ] 3.1 Update Elm types to include `isClustering` field
- [ ] 3.2 Add CSS for animated dots indicator in `public/timeline.css`
- [ ] 3.3 Implement the indicator in `ui/src/Pages/Home_.elm` (near grouping counts)
- [ ] 3.4 Ensure the indicator visibility reacts to the API state

## 4. Verification

- [ ] 4.1 Run `nix develop . --command crystal spec` to ensure no regressions
- [ ] 4.2 Verify clustering logic reliability (items correctly grouped after background task finishes)

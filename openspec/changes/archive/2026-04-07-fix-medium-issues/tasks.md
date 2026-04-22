## 1. Performance Fixes

- [ ] 1.1 In `src/controllers/admin_controller.cr`, batch delete orphaned feeds and items instead of looping per feed
- [ ] 1.2 In `src/repositories/feed_repository.cr`, implement batch INSERT for items using UNION ALL or multi-row INSERT

## 2. Unbounded Memory Growth Fix

- [ ] 2.1 In `src/repositories/cluster_repository.cr`, add `LIMIT 1000` to `find_all` and add pagination support

## 3. Consistency Fixes

- [ ] 3.1 In `src/websocket/event_broadcaster.cr`, change `HeartbeatEvent` to use `Time.utc`
- [ ] 3.2 In `src/utils.cr`, fix `UrlNormalizer.normalize` to not unconditionally add trailing slash

## 4. Edge Case Fixes

- [ ] 4.1 In `src/controllers/proxy_controller.cr`, fix `max` parameter to use `to_i64?` with default fallback instead of `to_i64`

## 5. Debug Cleanup

- [ ] 5.1 Remove `console.log` statements from `frontend/src/lib/stores/timelineStore.svelte.ts`

## 6. Verification

- [ ] 6.1 Run `just nix-build`
- [ ] 6.2 Run Crystal tests: `nix develop . --command crystal spec`
- [ ] 6.3 Run frontend tests: `cd frontend && npm run test`
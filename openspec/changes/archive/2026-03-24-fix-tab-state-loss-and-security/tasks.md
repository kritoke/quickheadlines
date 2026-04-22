## 1. Frontend Tab State Fixes

- [x] 1.1 Add URL-watching $effect to +page.svelte (feed view) that reloads when URL tab differs from feedState.activeTab
- [x] 1.2 Fix handleTabChange in +page.svelte to call loadFeeds before navigateToFeeds, remove setTimeout debounce
- [x] 1.3 Change timeline/+page.svelte initialized from plain let to $state(false)
- [x] 1.4 Fix handleTabChange in timeline/+page.svelte to call navigateToTimeline first, then let URL-watcher trigger loadTimeline
- [x] 1.5 Verify tab state persists when switching between feed and timeline views

## 2. Backend Security Fixes

- [x] 2.1 Fix favicon path traversal in api_controller.cr: validate hash with /\A[a-f0-9]{8,64}\z/ and ext with allowlist
- [x] 2.2 Fix IPv6 address parsing in quickheadlines.cr: use Socket::IPAddress instead of string split
- [x] 2.3 Fix exception message leakage in api_controller.cr: return generic message, log to STDERR
- [x] 2.4 Add SSRF prevention for feed redirects in feed_fetcher.cr: validate redirect targets against private IP ranges

## 3. Backend Logic Bug Fixes

- [x] 3.1 Fix feed_more pagination in api_controller.cr: use correct offset when slicing items (data.items[offset...offset+limit])
- [x] 3.2 Fix messages_sent double-count in socket_manager.cr: remove increment from broadcast method
- [x] 3.3 Fix unregister double-decrement in socket_manager.cr: remove unregister_connection call from unregister method

## 4. Verification

- [x] 4.1 Run frontend tests: cd frontend && npm run test
- [x] 4.2 Build with just nix-build (may need 3x for CSS changes)
- [x] 4.3 Run Crystal specs: nix develop . --command crystal spec
- [ ] 4.4 Verify tab persistence manually by testing feed ↔ timeline view switching

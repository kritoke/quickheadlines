## 1. Mobile Tab Navigation on Timeline

- [ ] 1.1 Add TabSelector import to timeline/+page.svelte
- [ ] 1.2 Add mobile TabSelector component below AppHeader in timeline view
- [ ] 1.3 Add CSS spacer div for mobile tab row (matching feed page pattern)
- [ ] 1.4 Test mobile tab navigation on timeline view

## 2. Shared App State Store

- [ ] 2.1 Create new file: frontend/src/lib/stores/appState.svelte.ts
- [ ] 2.2 Implement appState with tabs array and activeTab
- [ ] 2.3 Add loadTabs() function that calls /api/tabs endpoint
- [ ] 2.4 Update feed page to import and use appState for tabs
- [ ] 2.5 Update timeline page to import and use appState for tabs
- [ ] 2.6 Test state synchronization between views

## 3. Backend Tabs API Endpoint

- [ ] 3.1 Add new endpoint: GET /api/tabs in api_controller.cr
- [ ] 3.2 Implement lightweight tab response (just names)
- [ ] 3.3 Test /api/tabs returns quickly without feed data

## 4. Proxy URL Validation

- [ ] 4.1 Add ALLOWED_DOMAINS constant to api_controller.cr
- [ ] 4.2 Add validate_proxy_url method
- [ ] 4.3 Apply validation in proxy_image endpoint
- [ ] 4.4 Return 400 with "Domain not allowed" for invalid URLs
- [ ] 4.5 Add tests for allowed and blocked domains

## 5. Rate Limiting

- [ ] 5.1 Create rate_limiter.cr in src/ directory
- [ ] 5.2 Implement TokenBucket rate limiter with memory cleanup
- [ ] 5.3 Add middleware/annotation for /api/cluster endpoint
- [ ] 5.4 Add middleware/annotation for /api/admin endpoint
- [ ] 5.5 Return 429 with Retry-After header when limited
- [ ] 5.6 Test rate limiting behavior

## 6. Effects Consolidation

- [ ] 6.1 Refactor effects.svelte.ts to share code between feed and timeline
- [ ] 6.2 Extract common base functions
- [ ] 6.3 Ensure both views still work correctly after refactor

## 7. Build and Verify

- [ ] 7.1 Run: just nix-build
- [ ] 7.2 Run: nix develop . --command crystal spec
- [ ] 7.3 Run: cd frontend && npm run test
- [ ] 7.4 Take mobile screenshot of timeline to verify tabs work
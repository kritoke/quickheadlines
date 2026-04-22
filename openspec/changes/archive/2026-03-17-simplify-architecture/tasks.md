## 1. Backend Simplifications

- [x] 1.1 Remove unused `cluster_uncategorized` method from clustering_service.cr
- [x] 1.2 Simplify configuration by removing per-feed retry/timeout settings from Feed struct in config.cr
- [x] 1.3 Remove rate limiting configuration support from config.cr and related code
- [x] 1.4 Remove HTTP client advanced settings (proxy, custom User-Agent) from config.cr
- [x] 1.5 Remove feed authentication support from config.cr and fetcher code
- [x] 1.6 Keep global state singletons (working as intended)
- [x] 1.7 Update all config validation and loading logic to handle simplified configuration

## 2. Frontend Simplifications

- [x] 2.1 Keep design tokens (minimal and useful)
- [x] 2.2 Keep existing components (no unnecessary ones found)
- [x] 2.3 Keep WebSocket effects handlers (minimal duplication)
- [x] 2.4 Keep scroll position tracking (working well)
- [x] 2.5 Clean up any dead code or unused imports in frontend components

## 3. Verification and Testing

- [x] 3.1 Verify software releases feature works with all platforms (GitHub, GitLab, Codeberg)
- [x] 3.2 Confirm all 10 themes display correctly with cursor trail functionality
- [x] 3.3 Test clustering functionality with LSH-based implementation only
- [x] 3.4 Validate simplified configuration works with essential options only
- [x] 3.5 Run Crystal specs and Svelte tests to ensure no regressions
- [x] 3.6 Build and test application end-to-end with just nix-build

## 4. Documentation and Cleanup

- [x] 4.1 Update feeds.yml example with simplified configuration options
- [x] 4.2 Document removed configuration options and migration guidance
- [x] 4.3 Clean up any remaining references to removed features in code comments
- [x] 4.4 Verify build succeeds with just nix-build command
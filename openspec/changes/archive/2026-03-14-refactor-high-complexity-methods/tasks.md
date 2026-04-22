## 1. Fix Auto-fixable Issues

- [x] 1.1 Remove useless assignment in src/favicon_storage.cr line 27
- [x] 1.2 Verify Ameba passes on the fixed file

## 2. Refactor High Complexity Methods (>15)

- [x] 2.1 Refactor scripts/backfill_header_themes.cr main function (complexity 22)
  - [x] 2.1.1 Extract load_feeds_from_db method
  - [x] 2.1.2 Extract process_feed_with_fallbacks method  
  - [x] 2.1.3 Extract extract_and_save_theme method
  - [x] 2.1.4 Extract handle_google_favicon_fallback method
  - [x] 2.1.5 Verify complexity reduced to ≤12 and script still works

- [x] 2.2 Refactor src/fetcher/favicon.cr fetch_favicon_uri method (complexity 20)
  - [x] 2.2.1 Extract handle_redirect_response method
  - [x] 2.2.2 Extract handle_gray_placeholder_fallback method
  - [x] 2.2.3 Extract validate_and_save_favicon method
  - [x] 2.2.4 Verify complexity reduced to ≤12 and all favicon tests pass

- [x] 2.3 Refactor src/fetcher/feed_fetcher.cr fetch method (complexity 19)
  - [x] 2.3.1 Extract fetch_standard_rss_feed method
  - [x] 2.3.2 Ensure fetch_reddit_feed is properly separated
  - [x] 2.3.3 Extract fetch_github_releases_feed method
  - [x] 2.3.4 Verify complexity reduced to ≤12 and all feed types work

- [x] 2.4 Refactor src/fetcher/refresh_loop.cr refresh_all method (complexity 17)
  - [x] 2.4.1 Extract get_feeds_to_refresh method
  - [x] 2.4.2 Extract refresh_single_feed_safely method
  - [x] 2.4.3 Extract update_health_metrics method
  - [x] 2.4.4 Verify complexity reduced to ≤12 and refresh loop works

## 3. Refactor Moderate Complexity Methods (13-15)

- [x] 3.1 Refactor src/services/clustering_service.cr compute_cluster_for_item method (complexity 15)
  - [x] 3.1.1 Extract find_lsh_candidates_for_item method
  - [x] 3.1.2 Extract calculate_best_match_similarity method
  - [x] 3.1.3 Extract assign_to_cluster_or_create_new method
  - [x] 3.1.4 Verify complexity reduced to ≤12 and clustering works

- [x] 3.2 Refactor src/controllers/api_controller.cr save_header_color method (complexity 14)
  - [x] 3.2.1 Extract validate_request_body method
  - [x] 3.2.2 Extract normalize_and_find_feed_url method
  - [x] 3.2.3 Extract check_manual_override method
  - [x] 3.2.4 Verify complexity reduced to ≤12 and API endpoint works

- [x] 3.3 Refactor other API controller methods with complexity 13-14
  - [x] 3.3.1 Identify all methods with complexity 13-14
  - [x] 3.3.2 Apply extract method pattern to reduce complexity
  - [x] 3.3.3 Verify all API endpoints maintain identical behavior

## 4. Verification and Testing

- [x] 4.1 Run Ameba linter and verify no cyclomatic complexity warnings
- [ ] 4.2 Run crystal spec and verify all tests pass
- [x] 4.3 Run just nix-build and verify successful compilation
- [ ] 4.4 Test manual functionality (feed fetching, favicon handling, clustering)
- [ ] 4.5 Verify performance benchmarks are within acceptable ranges

## 5. Documentation and Cleanup

- [ ] 5.1 Update any relevant documentation if needed
- [ ] 5.2 Clean up any temporary debug code
- [ ] 5.3 Final verification that all specs are met
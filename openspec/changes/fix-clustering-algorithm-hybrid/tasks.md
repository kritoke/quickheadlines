## 1. Hybrid Algorithm Foundation

- [x] 1.1 Implement `STOP_WORDS` set and `remove_stop_words` utility in `ClusteringService`
- [x] 1.2 Implement `jaccard_similarity` utility for comparing normalized headline strings
- [x] 1.3 Add `SHORT_HEADLINE_THRESHOLD` (0.85) and `MIN_WORDS_FOR_CLUSTERING` (4) constants

## 2. Core Clustering Logic

- [x] 2.1 Update `compute_cluster_for_item` to implement the two-pass logic
- [x] 2.2 pass 1: Retrieve LSH candidates from `FeedCache` (existing)
- [x] 2.3 pass 2: Iterate through candidates and verify using `jaccard_similarity`
- [x] 2.4 Apply length-aware thresholds in the verification pass
- [x] 2.5 Ensure the best match (highest similarity above threshold) is selected as the cluster representative

## 3. Integration & Refinement

- [x] 3.1 Update `process_feed_item_clustering` to ensure signatures are updated with new normalization
- [x] 3.2 Add debug logging to `ClusteringService` to track clustering accuracy during development
- [x] 3.3 Verify that the `/api/run-clustering` endpoint correctly triggers the hybrid algorithm

## 4. Verification

- [x] 4.1 Create a Crystal spec test file for `ClusteringService` with sample headlines (similar vs different)
- [x] 4.2 Run `nix develop . --command crystal spec` and ensure all tests pass
- [ ] 4.3 Manually verify clustering results in the UI using the `/api/run-clustering` trigger

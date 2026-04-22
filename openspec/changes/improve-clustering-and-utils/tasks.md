## 1. Feed URL Validation

- [x] 1.1 Add `Utils.validate_feed_url(url : String) : Bool` method to `src/utils.cr`
- [x] 1.2 Add `Config.validate_feed_urls! : Nil` method that checks all feed URLs and raises on invalid
- [x] 1.3 Integrate validation call in `Application.initial_config` after config load
- [x] 1.4 Add unit tests for URL validation covering http, https, and invalid schemes

## 2. Unify Clustering Implementation

- [x] 2.1 Add `ClusteringEngine.find_similar_for_item(item : ClusteringItem, threshold : Float64, bands : Int32) : Array(Tuple(Int64, Float64))` method
- [x] 2.2 Analysis: Existing `compute_cluster_for_item` already uses LSH via `cache.find_lsh_candidates()` - this queries the database for candidates sharing LSH bands, then does exact matching on those candidates. This IS proper LSH usage (band-based candidate selection + exact verification).
- [x] 2.3 Analysis: Both `recluster_all` and `recluster_with_lsh` use the same overlap coefficient threshold (0.35). The difference is that `recluster_all` processes items one-by-one storing LSH bands in DB, while `recluster_with_lsh` builds an in-memory index.
- [x] 2.4 The implementation is already unified - both paths use LSH bands for candidate selection. No change needed.

## 3. Extract IP Parsing Utility

- [x] 3.1 Add `Utils.parse_ip_address(address : String) : String?` method to `src/utils.cr`
- [x] 3.2 Handle IPv4, IPv6, bracketed IPv6 formats in the implementation
- [x] 3.3 Refactor `src/quickheadlines.cr` to use the new utility method
- [x] 3.4 Add spec tests for IP parsing covering IPv4, IPv6, localhost, bracketed formats

## 4. Relocate and Integrate Tests

- [x] 4.1 Remove `scripts/test_color_extractor.cr` (functionality already covered in existing specs)
- [x] 4.2 Verify tests run with `crystal spec`
- [x] 4.3 scripts/ directory retained (contains other utility scripts)

## 5. Build Verification

- [x] 5.1 Run `just nix-build` to verify changes compile
- [x] 5.2 Run `nix develop . --command crystal spec` to verify tests pass

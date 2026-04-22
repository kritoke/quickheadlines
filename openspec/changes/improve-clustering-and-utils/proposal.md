## Why

The codebase has accumulated several code quality and maintainability issues that impact reliability and performance:

1. **Inconsistent Clustering Implementation**: Two clustering paths exist - `recluster_with_lsh` uses proper MinHash LSH via `LexisMinhash::LSHIndex`, while `compute_cluster_for_item` generates bands but falls back to brute-force O(n) candidate verification, negating LSH benefits
2. **Complex IP Parsing Logic**: WebSocket IP address extraction in `src/quickheadlines.cr` is 20+ lines of complex parsing logic with no unit tests
3. **Scattered Test File**: `scripts/test_color_extractor.cr` is not integrated with the main test suite
4. **No Feed URL Validation**: Startup has no validation of feed URLs, leading to silent failures for misconfigured feeds

## What Changes

1. **Unify Clustering Implementation**: Refactor `compute_cluster_for_item` to use the existing `ClusteringEngine.find_similar_pairs_lsh` method, ensuring consistent LSH-based clustering across all code paths
2. **Extract IP Parsing Utility**: Move WebSocket IP address parsing to `src/utils.cr` as a reusable, tested utility method
3. **Relocate Test File**: Move `scripts/test_color_extractor.cr` to `spec/color_extractor_spec.cr` and integrate with `crystal spec`
4. **Add Feed URL Validation**: Implement startup validation for feed URLs in `feeds.yml` with clear error messages for invalid endpoints

## Capabilities

### New Capabilities
- `feed-url-validation`: Validate all feed URLs during application startup to ensure they point to accessible RSS/Atom endpoints. Provides clear error messages identifying which feeds are invalid.

### Modified Capabilities
- (none - clustering improvements are implementation details that don't change stated requirements)

## Impact

### Affected Code
- `src/services/clustering_service.cr` - Refactor to use unified LSH clustering
- `src/services/clustering_engine.cr` - Potential additions to support single-item clustering via LSH
- `src/quickheadlines.cr` - Extract IP parsing logic
- `src/utils.cr` - Add IP parsing utility method
- `src/application.cr` or `src/config.cr` - Add feed URL validation
- `scripts/test_color_extractor.cr` - Relocate to `spec/`

### Testing
- Add spec for IP parsing utility covering IPv4, IPv6, bracketed IPv6, and edge cases
- Integrate color extractor tests with main test suite

### Dependencies
- No new dependencies required - using existing `lexis-minhash` library properly

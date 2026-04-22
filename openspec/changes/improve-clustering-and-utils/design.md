## Context

The QuickHeadlines codebase has several code quality and maintainability issues identified during a recent review:

**Clustering Inconsistency**: The codebase has two clustering code paths with different implementations:
- `recluster_with_lsh` uses `ClusteringEngine.find_similar_pairs_lsh` which properly leverages `LexisMinhash::LSHIndex` for efficient candidate lookup via banding
- `compute_cluster_for_item` (used by `recluster_all`) generates MinHash signatures and LSH bands but then uses brute-force O(n) iteration through all items to find matches, negating the performance benefits of LSH

**WebSocket IP Parsing**: The IP address extraction logic in `src/quickheadlines.cr` (lines 15-32) handles IPv4, IPv6, and bracketed IPv6 formats but is 20+ lines of inline code with no unit tests, making it difficult to verify correctness or reuse elsewhere.

**Test Organization**: `scripts/test_color_extractor.cr` exists outside the main test suite structure, making it easy to forget to run and not integrated with `crystal spec`.

**No Feed URL Validation**: The application loads feeds from `feeds.yml` without validating URLs, leading to silent failures when feeds become unavailable or URLs are misconfigured.

## Goals / Non-Goals

**Goals:**
- Unify clustering to use proper LSH-based candidate lookup consistently across all code paths
- Extract IP parsing into a reusable, testable utility function
- Integrate scattered test file with main test suite
- Add startup validation for feed URLs with actionable error messages

**Non-Goals:**
- Not changing the clustering algorithm itself (MinHash + overlap coefficient is retained)
- Not adding new clustering features or changing thresholds
- Not modifying the single-file `feeds.yml` deployment model
- Not implementing feed URL live monitoring (only startup validation)

## Decisions

### Decision 1: Refactor `compute_cluster_for_item` to use LSH Index

**Choice**: Add a method to `ClusteringEngine` that uses `LexisMinhash::LSHIndex` for single-item clustering, rather than modifying `FeedCache` to store an in-memory index.

**Rationale**: The existing `LexisMinhash::LSHIndex` class already provides efficient `find_similar_pairs`. Creating a single-item lookup method that adds the item to a temporary index or uses the existing index structure avoids duplicating LSH logic.

**Alternative**: Could modify `FeedCache` to maintain a persistent `LSHIndex`. However, this adds complexity to the cache layer and introduces serialization concerns for the index state.

**Alternative**: Could use `find_similar_pairs_lsh` in batch mode even for single items. This is the cleanest approach - wrap single-item clustering to use the batch method by processing one item at a time through the same LSH index.

### Decision 2: Extract IP Parsing to `src/utils.cr`

**Choice**: Create a `Utils.parse_ip_address(address_string : String) : String?` method that returns the IP address portion from various `remote_address` formats.

**Rationale**: Centralizes complex string parsing logic in a well-known location (`utils.cr` already exists) and enables unit testing without needing WebSocket infrastructure.

**Alternative**: Could create a dedicated `src/utils/ip_parser.cr` file. However, the IP parsing is only ~20 lines and doesn't warrant a separate file given the codebase convention.

### Decision 3: Move test file to `spec/` directory

**Choice**: Move `scripts/test_color_extractor.cr` to `spec/color_extractor_spec.cr` following Crystal conventions.

**Rationale**: Crystal spec files conventionally live in `spec/` and run via `crystal spec`. The `scripts/` directory appears to be for one-off utilities, not tests.

**Alternative**: Could rename `scripts/` to `spec/` in `shard.yml` or `crystal.yml`. However, the convention is clear - spec files go in `spec/`.

### Decision 4: Add Feed URL Validation During Config Load

**Choice**: Add validation in `Config.load` or early in `Application.initial_config` that attempts to parse each feed URL and verify it has a valid scheme (http/https).

**Rationale**: Minimal validation catches configuration errors early. Full reachability checking would add startup latency and complexity.

**Alternative**: Could perform full HTTP HEAD requests to verify feeds are reachable. This adds significant startup time and may be blocked by rate limiting on large feed sets.

## Risks / Trade-offs

[Risk] **Breaking existing clustering behavior**: Changing `compute_cluster_for_item` to use LSH properly may produce slightly different cluster assignments due to the band-based candidate generation in `LexisMinhash::LSHIndex`.

→ **Mitigation**: The new behavior is more correct (consistent with `recluster_with_lsh`). Run both methods and compare outputs to verify similarity.

[Risk] **Test file location change**: Moving test files may break CI/CD if scripts reference the old path.

→ **Mitigation**: Verify CI configuration references `spec/` not `scripts/`.

[Risk] **IP parsing edge cases**: The current implementation handles common cases but may have edge cases for unusual IPv6 representations.

→ **Mitigation**: Add comprehensive test coverage for IPv4, IPv6, bracketed IPv6, and localhost variants.

[Risk] **Overly strict URL validation**: Requiring http/https scheme may reject valid feeds with other schemes (e.g., custom protocols).

→ **Mitigation**: Allow any scheme that `URI.parse` accepts, or make validation configurable.

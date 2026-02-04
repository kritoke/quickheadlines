## 1. Dependency and Setup

- [x] 1.1 Add lexis-minhash ~> 0.1.0 dependency to shard.yml
- [x] 1.2 Run `nix develop . --command shards install` to install lexis-minhash

## 2. Database Schema

- [x] 2.1 Check if minhash_signature column exists in items table
- [x] 2.2 Create migration script to add minhash_signature BLOB column if missing
- [x] 2.3 Test migration with existing database

## 3. FeedCache Signature Storage

- [x] 3.1 Add store_item_signature(item_id, signature) method to FeedCache using LexisMinhash::Engine.signature_to_bytes
- [x] 3.2 Add get_item_signature(item_id) method to FeedCache using LexisMinhash::Engine.bytes_to_signature
- [x] 3.3 Add LSH band index to FeedCache (band → Set(item_id) mapping)
- [x] 3.4 Add store_lsh_bands(item_id, bands) method to FeedCache
- [x] 3.5 Add find_lsh_candidates(signature) method to FeedCache using band index

## 4. ClusteringService Integration

- [x] 4.1 Add require "lexis-minhash" to src/services/clustering_service.cr
- [x] 4.2 Update compute_cluster_for_item to compute MinHash signature using LexisMinhash::SimpleDocument
- [x] 4.3 Update compute_cluster_for_item to generate LSH bands using LexisMinhash::Engine.generate_bands
- [x] 4.4 Update compute_cluster_for_item to find candidates via FeedCache.find_lsh_candidates
- [x] 4.5 Update compute_cluster_for_item to estimate similarity using LexisMinhash::Engine.similarity
- [x] 4.6 Remove ClusteringUtilities.hybrid_similarity, jaccard_similarity, word_coverage_similarity (or comment out)
- [x] 4.7 Keep word count filtering (MIN_WORDS_FOR_CLUSTERING = 5)

## 5. Favicon and Storage Updates

- [x] 5.1 Update src/storage.cr to use LexisMinhash::Engine for signature serialization (if any references remain)

## 6. Testing

- [x] 6.1 Run clustering with sample headlines to verify MinHash signature generation
- [x] 6.2 Test LSH candidate discovery (verify O(1) lookup)
- [x] 6.3 Verify clustering quality (compare old vs. new results)
- [x] 6.4 Run `nix develop . --command crystal spec` to ensure no regressions
- [x] 6.5 Run Playwright tests: `nix develop . --command npx playwright test`

## 7. Code Review Fixes

- [x] 7.1 Remove duplicate sync_favicon_paths method (dead code with undefined max_size variable)
- [x] 7.2 Add cleanup_lsh_band_index method to refresh index after item deletions
- [x] 7.3 Call cleanup_lsh_band_index in cleanup_old_articles after deletions

## 8. Final Verification

- [x] 8.1 Clear old clustering metadata (cluster_id, lsh_bands) to ensure clean MinHash reindexing
  - Note: Run `clear_clustering_metadata()` before testing to ensure fresh MinHash indexing
  - Example: `nix develop . --command crystal eval 'require "./src/storage"; cache = FeedCache.new(nil); cache.clear_clustering_metadata'`

- [x] 6.1 Run clustering with sample headlines to verify MinHash signature generation
- [x] 6.2 Test LSH candidate discovery (verify O(1) lookup)
- [x] 6.3 Verify clustering quality (compare old vs. new results)
- [x] 6.4 Run `nix develop . --command crystal spec` to ensure no regressions
- [x] 6.5 Run Playwright tests: `nix develop . --command npx playwright test`

## 7. Documentation and Cleanup

- [x] 7.1 Remove or comment out obsolete ClusteringUtilities methods (hybrid_similarity, jaccard_similarity, word_coverage_similarity)
- [x] 7.2 Update inline comments in ClusteringService to reference MinHash/LSH
- [x] 7.3 Run `nix develop . --command nix develop . --command crystal tool format` to format code

## 8. Final Verification

- [x] 8.1 Verify clustering works correctly in development environment
- [x] 8.2 Monitor clustering performance (should be significantly faster with LSH)
- [x] 8.3 Check for any ameba linting issues: `nix develop . --command nix develop . --command ameba`

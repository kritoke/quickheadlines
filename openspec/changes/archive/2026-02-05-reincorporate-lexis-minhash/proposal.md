## Why

The clustering system currently uses direct Jaccard similarity and word coverage for story clustering, which requires computing similarity against all candidate items. As the dataset grows, this approach has O(n) complexity per clustering operation. The lexis-minhash shard provides MinHash with Locality-Sensitive Hashing (LSH) for efficient approximate similarity search, reducing candidate search to O(1) via hash bands. The shard is now more robust and ready for production use.

## What Changes

- Add lexis-minhash dependency (version ~> 0.1.0) to shard.yml
- Update ClusteringService to use LexisMinhash::Engine for:
  - Computing MinHash signatures from headlines
  - Generating LSH bands for candidate discovery
  - Estimating similarity using MinHash signatures
- Update FeedCache to store/retrieve MinHash signatures and LSH bands in database
- Add minhash_signature BLOB column to items table (if not present)
- Remove internal hybrid_similarity logic in favor of MinHash-based similarity estimation
- Keep word count filtering and stop-word handling (integrated into lexis-minhash)

## Capabilities

### New Capabilities
- **minhash-lsh-clustering**: Efficient approximate similarity clustering using MinHash signatures and Locality-Sensitive Hashing bands

### Modified Capabilities
- **hybrid-clustering**: Replace direct Jaccard/word-coverage similarity with MinHash-based similarity estimation for O(1) candidate search

## Impact

- **Code**: src/services/clustering_service.cr (use LexisMinhash::Engine), src/storage.cr (signature serialization), shard.yml (dependency)
- **Database**: items.minhash_signature column (BLOB) for storing MinHash signatures
- **Performance**: Candidate search reduced from O(n) to O(1) via LSH bands
- **Dependencies**: Add kritoke/lexis-minhash ~> 0.1.0

## 1. Dependencies Setup

- [ ] 1.1 Add embedding HTTP client shard (e.g., http托client with JSON support)
- [ ] 1.2 Create config/credentials.yml entry for EMBEDDING_API_KEY
- [ ] 1.3 Add base64 encoding shard for embedding storage

## 2. Embedding Service Implementation

- [ ] 2.1 Create src/services/embedding_service.cr
- [ ] 2.2 Implement HTTP client for embedding API (OpenAI-compatible)
- [ ] 2.3 Add batch embedding support (up to 100 headlines per request)
- [ ] 2.4 Implement caching by headline text (in-memory or Redis)
- [ ] 2.5 Add error handling for API failures
- [ ] 2.6 Write unit tests for embedding service

## 3. Database Schema Changes

- [ ] 3.1 Add nullable embedding column to items table (TEXT type for base64)
- [ ] 3.2 Create migration script for existing items
- [ ] 3.3 Add index on embedding for similarity search (or use pgvector)

## 4. Clustering Service Rewrite

- [ ] 4.1 Replace LSH candidate generation with embedding-based similarity search
- [ ] 4.2 Implement cosine similarity calculation for embedding vectors
- [ ] 4.3 Add fallback Jaccard similarity for short headlines (< 5 words)
- [ ] 4.4 Modify cluster assignment logic to use embedding similarity >= 0.75
- [ ] 4.5 Update compute_cluster_for_item to use new algorithm
- [ ] 4.6 Write unit tests for clustering service

## 5. Integration & Testing

- [ ] 5.1 Trigger re-clustering via /api/run-clustering
- [ ] 5.2 Verify SpaceX/xAI headlines now cluster together
- [ ] 5.3 Run Crystal specs to ensure no regressions
- [ ] 5.4 Run Playwright tests for UI consistency
- [ ] 5.5 Test performance with batch embedding of 500+ headlines

## 6. Documentation & Cleanup

- [ ] 6.1 Update README with embedding API configuration
- [ ] 6.2 Remove unused MinHash/LSH code from clustering_service.cr
- [ ] 6.3 Clean up lexis-minhash dependency if no longer needed

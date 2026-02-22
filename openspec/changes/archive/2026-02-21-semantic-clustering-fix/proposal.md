## Why

The current headline clustering algorithm uses MinHash/LSH with n-gram tokenization, which fails to cluster semantically similar headlines that are worded differently. For example, headlines about "SpaceX acquires xAI" use completely different phrasing and vocabulary, so their n-gram sets have minimal overlap, causing LSH to never propose them as clustering candidates. This results in duplicate stories appearing separately in the timeline, degrading user experience.

## What Changes

- Replace MinHash/LSH candidate generation with sentence embedding-based semantic similarity
- Store embedding vectors for each headline during ingestion
- Use cosine similarity to find candidate clusters based on meaning, not vocabulary
- Add new dependency for sentence embedding generation (e.g., transformers library or HTTP client for embedding API)
- Modify clustering service to use embedding similarity for both candidate generation and final matching

## Capabilities

### New Capabilities

- `semantic-clustering`: New capability for clustering headlines using sentence embeddings for semantic similarity detection
- `headline-embeddings`: New capability for generating and storing embedding vectors for headlines

### Modified Capabilities

- `story-clustering`: Modify clustering algorithm from n-gram/MinHash to embedding-based approach

## Impact

- `src/services/clustering_service.cr`: Complete rewrite of clustering algorithm
- `src/services/embedding_service.cr`: New service for generating headline embeddings
- `lib/`: New shards dependency for embedding generation
- Database schema: Add `embedding` column to `items` table
- Performance: Embedding generation is slower than MinHash; consider async processing

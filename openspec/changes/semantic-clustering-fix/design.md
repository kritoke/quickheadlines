## Context

Current clustering uses MinHash/LSH with n-gram tokenization. This approach works well for finding similar documents but fails for semantically similar headlines with different wording. The SpaceX/xAI example shows three headlines about the same story that share almost no n-grams but are clearly the same story semantically.

## Goals / Non-Goals

**Goals:**
- Cluster headlines by semantic meaning, not just shared vocabulary
- Handle paraphrased headlines with different word choices
- Maintain reasonable performance for real-time clustering
- Backward compatible with existing clustered data

**Non-Goals:**
- Perfect semantic understanding (use embeddings, not full NLP)
- Real-time streaming clustering (batch processing is acceptable)
- Cross-language clustering (English only)

## Decisions

### 1. Use Sentence Embeddings via External API

**Decision:** Use an embedding API (OpenAI text-embedding-3-small or HuggingFace Inference API) rather than attempting local embedding generation.

**Rationale:**
- Crystal has no mature local embedding libraries
- External APIs provide state-of-the-art embeddings
- Cost is minimal for short headlines
- Simpler implementation than building a custom solution

**Alternatives considered:**
- `transformers.cr` - Doesn't exist; only Python has good transformer models
- Local ONNX runtime - Would require significant C bindings work
- Word2vec-style custom solution - Lower quality, reinventing the wheel

### 2. Embedding Storage

**Decision:** Store embeddings as base64-encoded float32 arrays in a new `embedding` column.

**Rationale:**
- 384-dimensional embeddings (text-embedding-3-small) = 384 × 4 bytes = 1536 bytes
- PostgreSQL supports `vector` type but base64 text is more portable
- Can migrate to `pgvector` extension later if needed

### 3. Candidate Generation Strategy

**Decision:** Use vector similarity search (approximate nearest neighbors) instead of LSH.

**Rationale:**
- PostgreSQL with `pgvector` supports efficient ANN queries
- Simpler than maintaining separate LSH index
- Better recall for semantic similarity

**Threshold:** Cosine similarity >= 0.75 for clustering candidates

### 4. Fallback Hybrid Approach

**Decision:** Keep existing Jaccard/word similarity as fallback for headlines too short for embeddings.

**Rationale:**
- Short headlines (< 4 words) may not encode well in embeddings
- Existing algorithm works for exact/similar phrasing
- Graceful degradation

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| API latency adds clustering time | Batch embedding requests; use async HTTP |
| API cost for large datasets | Use smallest embedding model; cache results |
| API availability | Log errors; continue with fallback clustering |
| Embedding quality for short text | Fall back to Jaccard for headlines < 5 words |
| Database migration complexity | Add nullable column; populate async |

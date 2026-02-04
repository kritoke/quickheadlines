# semantic-clustering Specification

## Purpose
Cluster headlines using semantic similarity based on sentence embeddings rather than n-gram-based tokenization. This enables clustering of paraphrased headlines that share meaning but not vocabulary.

## Requirements
### Requirement: Embedding-Based Candidate Selection
The clustering system SHALL use cosine similarity of sentence embeddings to identify candidate clusters. Stories with embedding cosine similarity >= 0.75 SHALL be considered potential matches.

#### Scenario: Paraphrased Headlines Clustered
- **WHEN** two headlines "SpaceX acquires xAI" and "Elon Musk's SpaceX purchases his AI company xAI" have embedding cosine similarity of 0.82
- **THEN** the stories SHALL be assigned to the same cluster

#### Scenario: Unrelated Headlines Rejected
- **WHEN** two headlines "SpaceX acquires xAI" and "Apple releases new iPhone" have embedding cosine similarity of 0.45
- **THEN** the stories SHALL NOT be assigned to the same cluster

### Requirement: Fallback for Short Headlines
For headlines with fewer than 5 non-stop-words, the system SHALL fall back to Jaccard similarity on normalized text when embeddings may be unreliable.

#### Scenario: Short Headline Uses Fallback
- **WHEN** a headline has 3 words
- **THEN** the system SHALL use Jaccard similarity threshold of 0.85 for clustering decisions

### Requirement: Batch Embedding Generation
The system SHALL support batch embedding generation to minimize API calls. A batch of up to 100 headlines SHALL be embedded in a single request.

#### Scenario: Batch Processing Efficiency
- **WHEN** 50 new headlines are ingested
- **THEN** the system SHALL generate embeddings in a single batch API call rather than 50 individual calls

### Requirement: Embedding Storage
The system SHALL store headline embeddings in the database for future similarity comparisons without regenerating embeddings.

#### Scenario: Embedding Persistence
- **WHEN** a headline is embedded
- **THEN** the embedding vector SHALL be stored in the items table for reuse in subsequent clustering operations

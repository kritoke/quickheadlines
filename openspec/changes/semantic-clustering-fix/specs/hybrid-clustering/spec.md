# hybrid-clustering Specification

## Purpose
Cluster similar news stories using a hybrid approach combining embedding-based semantic similarity with fallback token-based matching for edge cases.

## Requirements
### Requirement: Embedding-Based Primary Clustering
The clustering system SHALL use sentence embedding cosine similarity as the primary clustering mechanism. Stories with embedding cosine similarity >= 0.75 SHALL be considered potential matches for the same cluster.

#### Scenario: High Semantic Similarity Clustering
- **WHEN** two stories have embedding cosine similarity of 0.82
- **THEN** the stories SHALL be assigned to the same cluster

#### Scenario: Low Semantic Similarity Rejection
- **WHEN** two stories have embedding cosine similarity of 0.45
- **THEN** the stories SHALL NOT be assigned to the same cluster

### Requirement: Fallback Token-Based Matching
For headlines with fewer than 5 non-stop-words, the system SHALL fall back to Jaccard similarity on normalized text when embeddings may be unreliable.

#### Scenario: Short Headline Uses Fallback
- **WHEN** a headline has fewer than 5 non-stop-words
- **THEN** the system SHALL use Jaccard similarity with 0.85 threshold for clustering decisions

#### Scenario: Short Headline Clustering with Fallback
- **WHEN** two short headlines have Jaccard similarity of 0.80
- **THEN** they SHALL NOT be clustered together due to the 0.85 threshold

### Requirement: Headline Normalization
The system SHALL normalize headlines by converting to lowercase, removing punctuation, and filtering out common stop-words (e.g., "the", "and", "says") before computing token-based similarity.

#### Scenario: Stop-word Filtering
- **WHEN** computing Jaccard similarity for "The Bitcoin price says experts are worried"
- **THEN** the words "the", "says", "are" MUST be excluded from the comparison

### Requirement: Batch Processing
The clustering system SHALL process headlines in batches to minimize API calls and database roundtrips. Each batch SHALL generate embeddings, find candidates, and cluster within a single pass.

#### Scenario: Batch Clustering
- **WHEN** 100 new headlines are ingested
- **THEN** the system SHALL generate embeddings in a single batch API call and cluster all items efficiently

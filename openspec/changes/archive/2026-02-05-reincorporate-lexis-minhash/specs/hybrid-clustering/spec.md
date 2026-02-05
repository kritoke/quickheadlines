# hybrid-clustering Specification

## Purpose

Cluster similar news stories using a hybrid approach combining MinHash-based similarity estimation with Locality-Sensitive Hashing for efficient candidate discovery.

## MODIFIED Requirements

### Requirement: Embedding-Based Primary Clustering
**BEFORE:** The clustering system SHALL use sentence embedding cosine similarity as the primary clustering mechanism. Stories with embedding cosine similarity >= 0.75 SHALL be considered potential matches for the same cluster.

**AFTER:** The clustering system SHALL use MinHash signature similarity estimation as the primary clustering mechanism. Stories with MinHash similarity >= 0.75 SHALL be considered potential matches for the same cluster.

#### Scenario: High Similarity Clustering
- **WHEN** two stories have MinHash similarity of 0.82
- **THEN** the stories SHALL be assigned to the same cluster

#### Scenario: Low Similarity Rejection
- **WHEN** two stories have MinHash similarity of 0.45
- **THEN** the stories SHALL NOT be assigned to the same cluster

### Requirement: Fallback Token-Based Matching
**BEFORE:** For headlines with fewer than 5 non-stop-words, the system SHALL fall back to Jaccard similarity on normalized text when embeddings may be unreliable.

**AFTER:** For headlines with fewer than 5 non-stop-words, the system SHALL NOT compute MinHash signatures and SHALL NOT assign clusters.

#### Scenario: Short Headline Excluded
- **WHEN** a headline has fewer than 5 non-stop-words
- **THEN** the system SHALL skip clustering for that headline

### Requirement: Headline Normalization
**BEFORE:** The system SHALL normalize headlines by converting to lowercase, removing punctuation, and filtering out common stop-words (e.g., "the", "and", "says") before computing token-based similarity.

**AFTER:** The system SHALL normalize headlines internally via LexisMinhash::SimpleDocument (lowercase, shingling, stop-word filtering) before computing MinHash signatures.

#### Scenario: Normalization via LexisMinhash
- **WHEN** a headline "The Bitcoin price says experts are worried" is processed
- **THEN** LexisMinhash::SimpleDocument SHALL apply normalization automatically

### Requirement: Batch Processing
**BEFORE:** The clustering system SHALL process headlines in batches to minimize API calls and database roundtrips. Each batch SHALL generate embeddings, find candidates, and cluster within a single pass.

**AFTER:** The clustering system SHALL process headlines in batches to minimize database roundtrips. Each batch SHALL generate MinHash signatures, find LSH candidates, and cluster within a single pass.

#### Scenario: Batch Clustering
- **WHEN** 100 new headlines are ingested
- **THEN** the system SHALL compute MinHash signatures and find LSH candidates in a single pass

## REMOVED Requirements

### Requirement: Hybrid Similarity Calculation
**Reason:** Replaced by MinHash-based similarity estimation via LexisMinhash::Engine
**Migration:** Use LexisMinhash::Engine.similarity(signature1, signature2) for all similarity calculations

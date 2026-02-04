# minhash-lsh-clustering Specification

## Purpose

Provide efficient approximate similarity clustering for news stories using MinHash signatures and Locality-Sensitive Hashing (LSH). Enables O(1) candidate discovery and scalable clustering as the dataset grows.

## ADDED Requirements

### Requirement: MinHash Signature Computation
The clustering system SHALL compute MinHash signatures for each headline using LexisMinhash::Engine with 100 hash functions.

#### Scenario: Compute Signature for Headline
- **WHEN** a headline "SpaceX acquires xAI for $2 billion" is processed
- **THEN** the system SHALL generate a 100-element MinHash signature using LexisMinhash::SimpleDocument

#### Scenario: Store Signature in Database
- **WHEN** a MinHash signature is computed
- **THEN** the system SHALL store the signature in the items.minhash_signature column as BLOB

#### Scenario: Retrieve Signature from Database
- **WHEN** an item's signature is needed for clustering
- **THEN** the system SHALL retrieve and deserialize the signature from the database

### Requirement: LSH Band Generation
The clustering system SHALL generate LSH bands from MinHash signatures using 20 bands with 5 rows per band for candidate discovery.

#### Scenario: Generate Bands for Candidate Search
- **WHEN** a MinHash signature is computed
- **THEN** the system SHALL generate 20 LSH bands (bands[0] = sig[0..4], bands[1] = sig[5..9], etc.)

#### Scenario: Index Bands for O(1) Lookup
- **WHEN** LSH bands are generated
- **THEN** the system SHALL store bands in FeedCache for O(1) candidate discovery

### Requirement: Candidate Discovery via LSH
The clustering system SHALL find candidate similar items by querying the LSH band index for items with at least one overlapping band.

#### Scenario: Find Candidates with Overlapping Bands
- **WHEN** a new headline has LSH bands [band1, band2, band3]
- **THEN** the system SHALL query FeedCache to find all items with matching band1, band2, or band3
- **AND** the union of results becomes the candidate set

#### Scenario: No Candidates Found
- **WHEN** LSH band query returns no overlapping items
- **THEN** the system SHALL create a new cluster for the item

### Requirement: MinHash Similarity Estimation
The clustering system SHALL estimate Jaccard similarity between headlines using MinHash signatures.

#### Scenario: Estimate Similarity Between Headlines
- **WHEN** two headlines have MinHash signatures sig1 and sig2
- **THEN** the system SHALL compute similarity using LexisMinhash::Engine.similarity(sig1, sig2)

#### Scenario: Cluster Based on Similarity Threshold
- **WHEN** MinHash similarity >= 0.75
- **THEN** the system SHALL assign the item to the existing cluster
- **WHEN** MinHash similarity < 0.75
- **THEN** the system SHALL create a new cluster

### Requirement: Word Count Filtering
The clustering system SHALL filter headlines with fewer than 5 non-stop-words before computing MinHash signatures.

#### Scenario: Short Headline Rejected
- **WHEN** a headline has fewer than 5 non-stop-words
- **THEN** the system SHALL NOT compute a MinHash signature
- **AND** the system SHALL NOT assign a cluster

#### Scenario: Valid Headline Processed
- **WHEN** a headline has 5 or more non-stop-words
- **THEN** the system SHALL compute MinHash signature and perform clustering

### Requirement: Database Schema
The items table SHALL include a minhash_signature column for storing serialized MinHash signatures.

#### Scenario: Check Schema Exists
- **WHEN** the system starts
- **THEN** the system SHALL verify minhash_signature column exists in items table

#### Scenario: Add Missing Column
- **WHEN** minhash_signature column does not exist
- **THEN** the system SHALL add the column via ALTER TABLE items ADD COLUMN minhash_signature BLOB

### Requirement: Backward Compatibility
The system SHALL handle existing items without MinHash signatures gracefully.

#### Scenario: Existing Item Without Signature
- **WHEN** an existing item has NULL minhash_signature
- **THEN** the system SHALL skip clustering for that item
- **OR** compute signature on-demand (implementation choice)

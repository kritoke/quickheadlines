# hybrid-clustering Specification

## Purpose
TBD - created by archiving change fix-clustering-algorithm-hybrid. Update Purpose after archive.
## Requirements
### Requirement: Two-Pass Similarity Verification
The clustering system SHALL use a two-pass algorithm to group similar news stories. The first pass MUST use Locality-Sensitive Hashing (LSH) for fast candidate identification. The second pass MUST perform a direct Jaccard similarity check on the normalized titles of candidates to verify grouping.

#### Scenario: High Precision Grouping
- **WHEN** two stories have similar LSH signatures but the second-pass Jaccard similarity of their titles is below 0.75
- **THEN** the stories SHALL NOT be assigned to the same cluster

#### Scenario: Verification Success
- **WHEN** two stories have similar LSH signatures and their second-pass Jaccard similarity is 0.75 or higher
- **THEN** the stories SHALL be assigned to the same cluster

### Requirement: Enhanced Headline Normalization
The system SHALL normalize headlines by converting to lowercase, removing punctuation, and filtering out common stop-words (e.g., "the", "and", "says") before computing signatures or similarity.

#### Scenario: Stop-word Filtering
- **WHEN** computing a signature for "The Bitcoin price says experts are worried"
- **THEN** the words "the", "says", "are" MUST be excluded from the shingles/features

### Requirement: Short Headline Protection
The system SHALL apply a stricter similarity threshold (0.85) for headlines with fewer than 5 non-stop-words to prevent false positive clustering of generic news terms.

#### Scenario: Short Headline Clustering
- **WHEN** two headlines have 4 non-stop-words and a similarity of 0.80
- **THEN** they SHALL NOT be clustered together due to the increased threshold for short headlines


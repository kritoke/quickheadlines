## MODIFIED Requirements

### Requirement: Two-Pass Similarity Verification
The clustering system SHALL use a two-pass algorithm to group similar news stories. The first pass MUST use Locality-Sensitive Hashing (LSH) for fast candidate identification. The second pass MUST perform a direct Jaccard similarity check on the normalized titles of candidates to verify grouping. The similarity threshold SHALL be tiered based on headline length to balance precision and recall.

#### Scenario: Short headline clustering (high precision)
- **WHEN** a headline has fewer than 5 non-stop-words
- **AND** the second-pass Jaccard similarity with a candidate is below 0.85
- **THEN** the stories SHALL NOT be assigned to the same cluster

#### Scenario: Short headline clustering success
- **WHEN** a headline has fewer than 5 non-stop-words
- **AND** the second-pass Jaccard similarity with a candidate is 0.85 or higher
- **THEN** the stories SHALL be assigned to the same cluster

#### Scenario: Medium headline clustering
- **WHEN** a headline has 5-7 non-stop-words
- **AND** the second-pass Jaccard similarity with a candidate is below 0.80
- **THEN** the stories SHALL NOT be assigned to the same cluster

#### Scenario: Medium headline clustering success
- **WHEN** a headline has 5-7 non-stop-words
- **AND** the second-pass Jaccard similarity with a candidate is 0.80 or higher
- **THEN** the stories SHALL be assigned to the same cluster

#### Scenario: Long headline clustering (lower threshold for more matches)
- **WHEN** a headline has 8 or more non-stop-words
- **AND** the second-pass Jaccard similarity with a candidate is below 0.75
- **THEN** the stories SHALL NOT be assigned to the same cluster

#### Scenario: Long headline clustering success
- **WHEN** a headline has 8 or more non-stop-words
- **AND** the second-pass Jaccard similarity with a candidate is 0.75 or higher
- **THEN** the stories SHALL be assigned to the same cluster

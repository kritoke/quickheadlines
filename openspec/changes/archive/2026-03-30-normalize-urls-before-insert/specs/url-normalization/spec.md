## ADDED Requirements

### Requirement: URL query parameters stripped during normalization
The system SHALL strip all query parameters from URLs during normalization to prevent duplicate items.

#### Scenario: UTM parameters removed
- **WHEN** normalizing URL `https://example.com/article?utm_source=twitter&utm_medium=link`
- **THEN** result is `https://example.com/article/`

#### Scenario: Multiple query parameters removed
- **WHEN** normalizing URL `https://example.com/page?a=1&b=2&c=3`
- **THEN** result is `https://example.com/page/

#### Scenario: URL without query params unchanged
- **WHEN** normalizing URL `https://example.com/article`
- **THEN** result is `https://example.com/article/`

### Requirement: URL fragments stripped during normalization
The system SHALL strip all fragment identifiers from URLs during normalization.

#### Scenario: Fragment removed
- **WHEN** normalizing URL `https://example.com/article#section`
- **THEN** result is `https://example.com/article/`

#### Scenario: Query and fragment both removed
- **WHEN** normalizing URL `https://example.com/article?utm_source=twitter#comments`
- **THEN** result is `https://example.com/article/`

### Requirement: Query params and fragments stripped before INSERT
The system SHALL use normalized URLs (without query params or fragments) when inserting items into the database.

#### Scenario: Duplicate from UTM-tagged URL prevented
- **WHEN** item with URL `https://example.com/article` is inserted
- **AND** another item with URL `https://example.com/article?utm_source=twitter` is inserted
- **THEN** both are treated as the same item due to unique index on (feed_id, normalized_link)

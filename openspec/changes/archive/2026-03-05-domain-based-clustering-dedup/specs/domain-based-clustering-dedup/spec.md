## ADDED Requirements

### Requirement: Clustering skips items from same base domain
The system SHALL NOT cluster items together if their feeds share the same base domain.

#### Scenario: Same domain feeds not clustered
- **WHEN** an item from `arstechnica.com` feed is compared with an item from `arstechnica.com/science` feed
- **THEN** they are not clustered together
- **AND** each item can be clustered with items from other domains

#### Scenario: Different domains can cluster
- **WHEN** an item from `arstechnica.com` is compared with an item from `theverge.com`
- **THEN** normal clustering logic applies
- **AND** they may be clustered if titles are similar

#### Scenario: Subdomains treated as same domain
- **WHEN** an item from `blog.example.com` is compared with `news.example.com`
- **THEN** they are not clustered together (same base domain `example.com`)

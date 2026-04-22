## ADDED Requirements

### Requirement: Canonical URL normalization
The system SHALL provide a single canonical `UrlNormalizer` module used project-wide for normalizing feed URLs. All cache lookups and feed comparisons SHALL use this normalization.

#### Scenario: Trailing slash removed
- **WHEN** `UrlNormalizer.normalize("https://example.com/feed/")` is called
- **THEN** the result is `"https://example.com/feed"` (no trailing slash)

#### Scenario: RSS/ATOM/feed suffixes stripped
- **WHEN** `UrlNormalizer.normalize("https://example.com/rss.xml")` is called
- **THEN** the result is `"https://example.com/"`
- **AND** `"https://example.com/feed.xml"` normalizes to `"https://example.com/"`
- **AND** `"https://example.com/atom"` normalizes to `"https://example.com/"`

#### Scenario: www prefix stripped for consistency
- **WHEN** `UrlNormalizer.normalize("https://www.example.com/feed")` is called
- **THEN** the result is `"https://example.com/feed"`

#### Scenario: HTTP upgraded to HTTPS
- **WHEN** `UrlNormalizer.normalize("http://example.com/feed")` is called
- **THEN** the result is `"https://example.com/feed"`

#### Scenario: All call sites use the same normalizer
- **WHEN** a feed URL is stored in the cache
- **AND** a subsequent request looks up the same feed
- **THEN** both use `UrlNormalizer.normalize` before cache operations
- **AND** cache lookups are consistent regardless of which code path performs them

### Requirement: Single normalize_url definition
The system SHALL have exactly one `normalize_url` function definition in the codebase. Duplicate implementations SHALL be removed.

#### Scenario: No duplicate normalize_url functions
- **WHEN** `grep -r "def normalize_url"` is run on `src/`
- **THEN** exactly one result is found in `src/utils.cr` within the `UrlNormalizer` module
- **AND** all other files call `UrlNormalizer.normalize` instead of defining their own

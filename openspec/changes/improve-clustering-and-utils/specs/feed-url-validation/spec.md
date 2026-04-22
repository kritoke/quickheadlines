## ADDED Requirements

### Requirement: Valid URL Scheme
The system SHALL only accept feed URLs with http or https schemes during configuration loading.

#### Scenario: Valid HTTPS URL Accepted
- **WHEN** a feed URL has scheme "https://"
- **THEN** the system SHALL accept the URL without error

#### Scenario: Valid HTTP URL Accepted
- **WHEN** a feed URL has scheme "http://"
- **THEN** the system SHALL accept the URL without error

#### Scenario: Invalid Scheme Rejected
- **WHEN** a feed URL has an invalid scheme (e.g., "ftp://", "file://")
- **THEN** the system SHALL report an error identifying the problematic feed URL

### Requirement: Parseable URL Structure
The system SHALL validate that each feed URL can be parsed as a valid URI with a host component.

#### Scenario: Well-Formed URL Accepted
- **WHEN** a feed URL is "https://example.com/feed.xml"
- **THEN** the system SHALL accept the URL as structurally valid

#### Scenario: Malformed URL Rejected
- **WHEN** a feed URL is "not a valid url"
- **THEN** the system SHALL report an error identifying the problematic feed URL

### Requirement: Startup Validation with Clear Error Messages
The system SHALL perform feed URL validation during application startup and report all invalid feeds in a single error message.

#### Scenario: Single Invalid Feed Reports Clearly
- **WHEN** one feed URL is invalid
- **THEN** the system SHALL exit with an error message listing the invalid URL and reason

#### Scenario: Multiple Invalid Feeds Reports All
- **WHEN** multiple feed URLs are invalid
- **THEN** the system SHALL report all invalid URLs in a single error message before exiting

#### Scenario: All Feeds Valid Proceeds Normally
- **WHEN** all feed URLs in feeds.yml are valid
- **THEN** the system SHALL proceed with normal startup

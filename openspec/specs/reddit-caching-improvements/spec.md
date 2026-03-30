# reddit-caching-improvements Specification

## Purpose
TBD - created by archiving change reddit-caching-improvements. Update Purpose after archive.
## Requirements
### Requirement: Reddit feeds use HTTP timeouts
The system SHALL apply connect and read timeouts to Reddit HTTP requests to prevent indefinite hanging.

#### Scenario: Request with timeouts
- **WHEN** fetching a Reddit feed
- **THEN** connect timeout of 10 seconds is applied
- **AND** read timeout of 30 seconds is applied

#### Scenario: Connect timeout exceeded
- **WHEN** Reddit server does not respond within 10 seconds of connect
- **THEN** request is aborted
- **AND** fallback to RSS is attempted

### Requirement: 304 responses capture updated cache headers
The system SHALL check for and use updated ETag and Last-Modified headers from 304 responses.

#### Scenario: 304 with updated ETag
- **WHEN** Reddit returns 304 with a new ETag header
- **THEN** the new ETag is captured for future requests
- **AND** previous_data is returned with the updated ETag

#### Scenario: 304 without new headers
- **WHEN** Reddit returns 304 without ETag or Last-Modified headers
- **THEN** existing cache headers are preserved
- **AND** previous_data is returned unchanged

### Requirement: Reddit fetcher methods have low cyclomatic complexity
The system SHALL use helper methods to keep individual method complexity below Ameba threshold (12).

#### Scenario: Helper method extraction
- **WHEN** code is analyzed by Ameba
- **THEN** no method exceeds cyclomatic complexity of 12
- **AND** helper methods are reusable across JSON and RSS fetching


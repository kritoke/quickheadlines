# api-input-validation Specification

## Purpose
Validates query parameters on all API endpoints to prevent invalid inputs from causing errors or unexpected behavior.

## ADDED Requirements

### Requirement: Limit parameter validation
The system SHALL validate the `limit` query parameter to ensure it is a positive integer within acceptable bounds.

#### Scenario: Valid limit
- **WHEN** a request includes `limit=50`
- **THEN** the limit is accepted as 50

#### Scenario: Invalid limit (negative)
- **WHEN** a request includes `limit=-5`
- **THEN** the limit is clamped to the default minimum (1)

#### Scenario: Invalid limit (exceeds max)
- **WHEN** a request includes `limit=10000`
- **THEN** the limit is clamped to the maximum allowed (1000)

#### Scenario: Invalid limit (non-numeric)
- **WHEN** a request includes `limit=abc`
- **THEN** the limit defaults to the endpoint's default value

### Requirement: Offset parameter validation
The system SHALL validate the `offset` query parameter to ensure it is a non-negative integer.

#### Scenario: Valid offset
- **WHEN** a request includes `offset=100`
- **THEN** the offset is accepted as 100

#### Scenario: Invalid offset (negative)
- **WHEN** a request includes `offset=-10`
- **THEN** the offset is clamped to 0

#### Scenario: Invalid offset (non-numeric)
- **WHEN** a request includes `offset=xyz`
- **THEN** the offset defaults to 0

### Requirement: Days parameter validation
The system SHALL validate the `days` query parameter to ensure it is a positive integer within the allowed range.

#### Scenario: Valid days
- **WHEN** a request includes `days=30`
- **THEN** the days is accepted as 30

#### Scenario: Invalid days (exceeds max)
- **WHEN** a request includes `days=500`
- **THEN** the days is clamped to 365

### Requirement: URL parameter validation
The system SHALL validate the `url` query parameter when required.

#### Scenario: Missing required URL
- **WHEN** a request to `/api/feed_more` omits the `url` parameter
- **THEN** the system returns a 400 Bad Request error

#### Scenario: Invalid URL format
- **WHEN** a request includes `url=` (empty string)
- **THEN** the system returns a 400 Bad Request error

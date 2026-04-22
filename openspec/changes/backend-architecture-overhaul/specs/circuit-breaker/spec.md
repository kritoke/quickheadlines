## ADDED Requirements

### Requirement: Circuit Breaker Pattern
The system SHALL implement circuit breaker for external API calls.

#### Scenario: Circuit opens after failures
- **WHEN** external API fails repeatedly
- **THEN** circuit breaker opens and fast-fails subsequent requests

#### Scenario: Circuit half-open
- **WHEN** circuit is open and timeout passes
- **THEN** circuit enters half-open state to test recovery

#### Scenario: Circuit closes after success
- **WHEN** circuit is half-open and request succeeds
- **THEN** circuit closes and normal operation resumes

## ADDED Requirements

### Requirement: Trusted proxy IP validation
The system SHALL validate X-Forwarded-For headers only from trusted proxies to prevent IP spoofing.

#### Scenario: Request from trusted proxy
- **WHEN** a WebSocket connection comes from a trusted proxy IP
- **AND** X-Forwarded-For header is present
- **THEN** the client IP is extracted from X-Forwarded-For

#### Scenario: Request from untrusted source
- **WHEN** a WebSocket connection comes from an untrusted IP
- **AND** X-Forwarded-For header is present
- **THEN** the X-Forwarded-For header is ignored
- **AND** the actual remote address is used

#### Scenario: No X-Forwarded-For header
- **WHEN** no X-Forwarded-For header is present
- **THEN** the remote address is used directly

### Requirement: Rate limiter IP extraction
The system SHALL use the same trusted proxy logic for rate limiting.

#### Scenario: Rate limit from trusted proxy
- **WHEN** rate limiting check is performed
- **AND** request comes from trusted proxy with X-Forwarded-For
- **THEN** the client IP is extracted from X-Forwarded-For

#### Scenario: Rate limit from untrusted source
- **WHEN** rate limiting check is performed
- **AND** request comes from untrusted source
- **THEN** the X-Forwarded-For is ignored
- **AND** the remote address is used

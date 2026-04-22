## ADDED Requirements

### Requirement: Admin endpoint supports actionable operations
The system SHALL support multiple actions on the `/api/admin` endpoint as specified by the request body.

#### Scenario: Clear cache action
- **WHEN** a POST request to `/api/admin` has body `{"action": "clear-cache"}`
- **THEN** all items and feeds are deleted from the database
- **AND** the response is `202 Accepted` with body `"Admin action started in background"`

#### Scenario: Cleanup orphaned action
- **WHEN** a POST request to `/api/admin` has body `{"action": "cleanup-orphaned"}`
- **THEN** feeds present in the database but not in the current config are removed
- **AND** the response is `202 Accepted` with body `"Admin action started in background"`

#### Scenario: Unknown action rejected
- **WHEN** a POST request to `/api/admin` has body `{"action": "unknown"}`
- **THEN** the server returns `400 Bad Request` with body `"Unknown action"`

#### Scenario: Action defaults to cleanup-orphaned
- **WHEN** a POST request to `/api/admin` has body `{}` or is missing the action field
- **THEN** the server returns `400 Bad Request` with body `"Missing action field"`

## REMOVED Requirements

### Requirement: Hardcoded cleanup-orphaned action
**Reason**: The `action` field was read from the request body but immediately overwritten with `action = "cleanup-orphaned"`, making the `clear-cache` path and request-body-driven action selection unreachable dead code. This fix makes the action field actually functional.

**Migration**: Update any clients that rely on the hardcoded behavior to explicitly send `{"action": "cleanup-orphaned"}` if that was the intended action.

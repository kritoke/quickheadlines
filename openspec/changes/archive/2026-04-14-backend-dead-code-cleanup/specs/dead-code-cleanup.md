## ADDED Requirements

### Requirement: No dead code remains after cleanup
The system SHALL compile and pass all tests after removing all code confirmed unreachable by `crystal tool unreachable`. No API endpoint behavior SHALL change.

#### Scenario: Build succeeds after cleanup
- **WHEN** all dead code identified in the proposal is removed
- **THEN** `just nix-build` completes successfully

#### Scenario: Tests pass after cleanup
- **WHEN** all dead code is removed
- **THEN** `nix develop . --command crystal spec` passes all tests

#### Scenario: API endpoints unchanged
- **WHEN** cleanup is complete
- **THEN** all existing API endpoints return identical responses

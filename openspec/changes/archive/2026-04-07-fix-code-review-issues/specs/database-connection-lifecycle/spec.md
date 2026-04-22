## ADDED Requirements

### Requirement: Database connection cleanup on initialization failure
The system SHALL ensure that SQLite database connections are properly closed when FeedCache initialization fails.

#### Scenario: Schema creation failure
- **WHEN** create_schema raises an exception during FeedCache initialization
- **THEN** any opened database connection is closed before the exception propagates
- **AND** no file handles are leaked

#### Scenario: Invalid database path
- **WHEN** the database path is inaccessible
- **THEN** the initialization raises a clear error
- **AND** no connection pool entries are left open

#### Scenario: Connection reuse via DatabaseService
- **WHEN** DatabaseService.instance already has an open connection
- **THEN** FeedCache reuses that connection instead of opening a new one
- **AND** the connection lifecycle is managed by DatabaseService

### Requirement: Consistent UTC timestamps in state
The system SHALL use Time.utc consistently for all state timestamps to avoid timezone-dependent comparison bugs.

#### Scenario: StateStore updated_at uses UTC
- **WHEN** StateStore.updated_at is set during refresh_all
- **THEN** it is set to Time.utc (not Time.local)
- **AND** comparisons with other UTC timestamps are deterministic

#### Scenario: Refresh loop config modification detection
- **WHEN** comparing config file modification time with stored mtime
- **THEN** both values are in the same timezone for accurate comparison

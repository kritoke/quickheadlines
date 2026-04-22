## ADDED Requirements

### Requirement: Schema version table for migrations
The system SHALL use a `schema_info` table to track the current database schema version and run migrations sequentially in version order.

#### Scenario: Migration runs exactly once
- **WHEN** database is at schema version 0
- **AND** migration version 1 has not been applied
- **THEN** migration 1 is applied
- **AND** `schema_info.version` is updated to 1
- **AND** migration 1 is NOT applied again on next startup

#### Scenario: Migration skipped if already applied
- **WHEN** database is at schema version 2
- **AND** migration 1 exists
- **THEN** migration 1 is skipped
- **AND** migrations 3+ proceed as normal

#### Scenario: Failed migration logs error and propagates
- **WHEN** a migration's `ALTER TABLE` statement fails (e.g., disk full, syntax error)
- **THEN** the exception message is logged to stderr with migration name and version
- **AND** the exception is re-raised, aborting startup

#### Scenario: Schema version initialized on new database
- **WHEN** a new database is created (no `schema_info` table exists)
- **THEN** `schema_info` table is created with `version = 0`
- **AND** all migrations are run from the beginning

### Requirement: Schema migration log output
The system SHALL log each migration as it runs.

#### Scenario: Migration produces log message
- **WHEN** migration N is applied to the database
- **THEN** a message is printed to stderr: `"[Schema] Running migration N: <description>"`
- **AND** on success: `"[Schema] Migration N applied (new version: N)"`

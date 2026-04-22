## ADDED Requirements

### Requirement: Migration System
The system SHALL provide a migration system using micrate for database schema changes.

#### Scenario: Run pending migrations
- **WHEN** migrations exist and database is at an older version
- **THEN** pending migrations are applied in order

#### Scenario: Rollback a migration
- **WHEN** a migration needs to be rolled back
- **THEN** the down.sql is executed to revert the change

### Requirement: Migration with Rollback
Each migration SHALL include both up and down SQL statements.

#### Scenario: Create a migration
- **WHEN** a developer creates a new migration
- **THEN** both up.sql and down.sql files are generated

### Requirement: Database Constraints
The system SHALL add database-level constraints for data integrity.

#### Scenario: Foreign key constraint
- **WHEN** a record with foreign key is inserted
- **THEN** invalid foreign keys are rejected at database level

#### Scenario: Not null constraint
- **WHEN** a required field is null
- **THEN** the database rejects the insert

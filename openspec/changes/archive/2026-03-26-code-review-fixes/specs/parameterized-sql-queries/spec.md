## ADDED Requirements

### Requirement: Parameterized SQL for IN Clauses

Database operations that use IN clauses with variable lists SHALL use parameterized queries with placeholder substitution.

#### Scenario: Cleanup uses parameterized query for URL list
- **WHEN** `CleanupRepository.cleanup_old_entries` is called with multiple URLs
- **THEN** the SQL SHALL use `?` placeholders for each URL
- **AND** URL values SHALL be passed as query arguments, not interpolated

#### Scenario: SQL injection prevented via parameterization
- **WHEN** a URL contains single quotes or SQL special characters
- **THEN** the value SHALL be safely passed via parameter binding
- **AND** no SQL syntax error SHALL occur

### Requirement: Safe String Interpolation Only for Constants

SQL string interpolation SHALL only be used for values that are constant and validated against a whitelist.

#### Scenario: Table/column names from constant sources
- **WHEN** ALTER TABLE statements are executed
- **THEN** table and column names SHALL come from constant definitions or validated against a whitelist
- **AND** user-provided values SHALL NOT be interpolated into DDL statements

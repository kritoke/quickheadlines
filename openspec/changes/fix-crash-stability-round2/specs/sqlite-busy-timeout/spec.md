## ADDED Requirements

### Requirement: SQLite busy timeout configured
The system SHALL set a busy_timeout on SQLite connections to allow retries when concurrent writes conflict.

#### Scenario: Concurrent write retries on SQLITE_BUSY
- **WHEN** two fibers attempt to write to the database simultaneously
- **THEN** the second writer waits up to 5000ms for the first to complete

#### Scenario: Busy timeout applied at connection open
- **WHEN** DatabaseService opens a connection
- **THEN** busy_timeout=5000 is set via connection string parameter

### Requirement: FreeBSD-compatible SQLite PRAGMAs
The system SHALL disable memory-mapped I/O and set wal_autocheckpoint for FreeBSD/ZFS stability.

#### Scenario: mmap disabled
- **WHEN** the database connection is opened
- **THEN** PRAGMA mmap_size is set to 0

#### Scenario: WAL autocheckpoint configured
- **WHEN** the database connection is opened
- **THEN** PRAGMA wal_autocheckpoint is set to 100

### Requirement: Bounded connection pool size
The system SHALL limit the maximum number of database connections to prevent memory exhaustion.

#### Scenario: Pool size limited
- **WHEN** DatabaseService opens a connection pool
- **THEN** max_pool_size is set to 5

### Requirement: Foreign keys enabled in all code paths
The system SHALL enable foreign_keys PRAGMA in both DatabaseService and top-level create_schema.

#### Scenario: Foreign keys ON in top-level create_schema
- **WHEN** create_schema is called from init_db or repair paths
- **THEN** PRAGMA foreign_keys is set to ON

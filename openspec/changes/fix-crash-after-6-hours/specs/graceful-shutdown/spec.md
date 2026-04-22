## ADDED Requirements

### Requirement: Database connections closed on shutdown
The system SHALL close database connections when the application terminates, preventing resource leaks.

#### Scenario: Database closed on normal exit
- **WHEN** the application exits normally (at_exit handlers run)
- **THEN** DatabaseService.close is called to close the database connection

#### Scenario: Database closed on unhandled exception
- **WHEN** an unhandled exception causes application termination
- **THEN** at_exit handlers still execute and close database connections

### Requirement: Graceful shutdown logging
The system SHALL log shutdown events for debugging purposes.

#### Scenario: Shutdown logged
- **WHEN** at_exit handler is invoked
- **THEN** a log message "Shutting down gracefully..." is emitted before cleanup

## ADDED Requirements

### Requirement: All logging uses AppLogger
All application code SHALL use AppLogger for output instead of STDERR.puts.

#### Scenario: Debug logging
- **WHEN** code calls `AppLogger.debug { "message" }`
- **THEN** message is logged at DEBUG level
- **THEN** message is not evaluated if DEBUG is disabled (lazy evaluation)

#### Scenario: Info logging
- **WHEN** code calls `AppLogger.info("message")`
- **THEN** message is logged at INFO level

#### Scenario: Warning logging
- **WHEN** code calls `AppLogger.warning("message")`
- **THEN** message is logged at WARNING level

#### Scenario: Error logging
- **WHEN** code calls `AppLogger.error("message")`
- **THEN** message is logged at ERROR level

### Requirement: Structured logging with context
Log messages SHALL include relevant context for debugging.

#### Scenario: Log with context
- **WHEN** code calls `AppLogger.info({ feed: url, items: count }, "Feed fetched")`
- **THEN** output includes feed URL and item count

### Requirement: No STDERR.puts in production code
Application code SHALL NOT use STDERR.puts for logging.

#### Scenario: Code review check
- **WHEN** grep runs on source files
- **THEN** no STDERR.puts found except in test files or startup scripts

## ADDED Requirements

### Requirement: Server startup errors shall be observable

The HTTP server startup process SHALL propagate fatal errors (binding failure, port already in use, unhandled exceptions from Athena framework) to the top-level exception handler and cause the process to exit with a non-zero status code.

#### Scenario: Port already in use
- **WHEN** the configured port (e.g., 8080) is already bound by another process
- **THEN** the server SHALL raise `Socket::Error` with `EADDRINUSE`
- **AND** the exception SHALL be caught by the top-level `rescue` block in `quickheadlines.cr`
- **AND** a fatal log message SHALL be emitted containing the exception details
- **AND** the process SHALL exit with code 1

#### Scenario: Server startup raises unexpected exception
- **WHEN** `ATH.run` raises any exception other than `Socket::Error` during initialization
- **THEN** the exception SHALL be caught by the top-level `rescue` block
- **AND** a fatal log message SHALL be emitted including the exception class and message
- **AND** the process SHALL exit with code 1

#### Scenario: Server starts successfully
- **WHEN** the port is available and `ATH.run` initializes without error
- **THEN** the HTTP server SHALL bind to `0.0.0.0` on the configured port
- **AND** the process SHALL remain running (not exit) while handling HTTP requests

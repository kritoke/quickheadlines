## ADDED Requirements

### Requirement: HTTP::Client connections closed after use
The system SHALL close HTTP::Client connections in ensure blocks to prevent file descriptor leaks.

#### Scenario: Proxy controller closes client on success
- **WHEN** proxy_image_fetch completes successfully
- **THEN** the HTTP::Client is closed

#### Scenario: Proxy controller closes client on error
- **WHEN** proxy_image_fetch raises an exception
- **THEN** the HTTP::Client is closed in the ensure block

#### Scenario: Favicon fetch closes clients on error
- **WHEN** fetch_and_save raises an exception
- **THEN** both the primary and redirect HTTP::Client are closed

### Requirement: Write timeout on all HTTP clients
The system SHALL set write_timeout on all HTTP::Client instances to prevent indefinite write blocking.

#### Scenario: Write timeout set on favicon client
- **WHEN** fetch_and_save creates an HTTP::Client
- **THEN** write_timeout is set to 10 seconds

#### Scenario: Write timeout set on proxy client
- **WHEN** proxy_image_fetch creates an HTTP::Client
- **THEN** write_timeout is set to 10 seconds

### Requirement: GitHub sync HTTP call has timeouts
The system SHALL set connect_timeout and read_timeout on the github_sync HTTP call.

#### Scenario: GitHub config download has timeouts
- **WHEN** download_github_config makes an HTTP request
- **THEN** connect_timeout and read_timeout are set

## ADDED Requirements

### Requirement: Correct MIME type for .woff files
The `.woff` file extension SHALL map to `font/woff`, not `font/woff2`.

#### Scenario: woff MIME type is correct
- **WHEN** a `.woff` file is served
- **THEN** the Content-Type header is `font/woff`

### Requirement: Auth check rescues only expected exception types
`check_admin_auth` SHALL catch `ArgumentError` only, not all `Exception` types.

#### Scenario: Programming error surfaces during auth
- **WHEN** a `NilAssertionError` or other programming error occurs during auth checking
- **THEN** the error propagates (is not silently caught)
- **THEN** `ArgumentError` from byte comparison is still caught

### Requirement: Shutdown errors are logged
`AppBootstrap#close` SHALL log database close errors instead of silently swallowing them.

#### Scenario: Database close error is visible
- **WHEN** the database close operation fails during shutdown
- **THEN** an error is logged with the exception message

### Requirement: Malformed admin requests are logged
`AdminController#parse_admin_action` SHALL log parse errors instead of silently returning nil.

#### Scenario: Malformed admin request logged
- **WHEN** an admin request body fails to parse
- **THEN** the parse error is logged with relevant context

### Requirement: HTTP timeouts use centralized constants
Favicon and proxy HTTP clients SHALL use timeout values from `Constants` module instead of hardcoded values.

#### Scenario: Favicon fetch uses Constants timeouts
- **WHEN** `FaviconStorage` creates an HTTP client
- **THEN** connect and read timeouts come from `Constants`

#### Scenario: Proxy fetch uses Constants timeouts
- **WHEN** `ProxyController` creates an HTTP client
- **THEN** connect and read timeouts come from `Constants`

### Requirement: Consistent IP extraction for HTTP and WebSocket
Both HTTP controllers and the WebSocket handler SHALL use the same IP extraction logic that respects `TRUSTED_PROXY` and `X-Forwarded-For`.

#### Scenario: WebSocket uses TRUSTED_PROXY-aware IP extraction
- **WHEN** a WebSocket connection is established
- **THEN** the client IP is extracted using the same `TRUSTED_PROXY`-aware logic as HTTP controllers

#### Scenario: Single IP extraction method
- **WHEN** client IP is needed anywhere in the codebase
- **THEN** a shared utility method is called
- **THEN** no duplicate IP extraction logic exists

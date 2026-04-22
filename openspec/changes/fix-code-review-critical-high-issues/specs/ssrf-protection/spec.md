## ADDED Requirements

### Requirement: SSRF protection for favicon fetching
`FaviconStorage.fetch_and_save()` SHALL validate the host of the final resolved URL after any HTTP redirects before making the connection. If the resolved host is a private, reserved, or loopback address, the request SHALL be rejected and no connection SHALL be made.

#### Scenario: Direct request to public host succeeds
- **WHEN** `fetch_and_save` is called with `https://example.com/favicon.ico`
- **AND** the host `example.com` is not a private/reserved host
- **THEN** the favicon is fetched and saved

#### Scenario: Redirect to public host succeeds
- **WHEN** `fetch_and_save` is called with `https://short.url/abc` that redirects to `https://example.com/favicon.ico`
- **AND** the final resolved host `example.com` is not a private/reserved host
- **THEN** the favicon is fetched and saved

#### Scenario: Redirect to private IP is blocked
- **WHEN** `fetch_and_save` is called with a URL that redirects to `http://169.254.169.254/latest/meta-data/`
- **THAN** the connection to the private IP SHALL be rejected
- **AND** `fetch_and_save` returns `nil`

#### Scenario: Redirect to loopback is blocked
- **WHEN** `fetch_and_save` is called with a URL that redirects to `http://127.0.0.1:8080/internal/api`
- **THEN** the connection to loopback SHALL be rejected
- **AND** `fetch_and_save` returns `nil`

#### Scenario: Redirect to private network is blocked
- **WHEN** `fetch_and_save` is called with a URL that redirects to `http://192.168.1.1/router-config`
- **THEN** the connection to the private network SHALL be rejected
- **AND** `fetch_and_save` returns `nil`

### Requirement: Use existing private host validation utility
The implementation SHALL use the existing `Utils.private_host?()` function to check resolved hosts. This function checks for RFC 1918 private addresses, loopback (127.0.0.0/8, ::1), link-local (169.254.0.0/16), and CGNAT (100.64.0.0/10) addresses.

## ADDED Requirements

### Requirement: Proxy URL validation
The system SHALL validate all URLs in the image proxy, including redirect targets.

#### Scenario: Initial URL validated
- **WHEN** a request is made to /proxy_image with url parameter
- **THEN** the URL is checked against allowed domains before fetching

#### Scenario: Redirect URLs validated
- **WHEN** the proxy follows a redirect
- **THEN** each redirect URL is validated against allowed domains
- **AND** the request is blocked if a redirect goes to an unallowed domain

#### Scenario: Private network blocking
- **WHEN** a redirect URL points to a private network (127.x, 192.168.x, 10.x, 172.16.x, 169.254.x, localhost)
- **THEN** the request is blocked

#### Scenario: Non-HTTP schemes blocked
- **WHEN** a redirect URL uses a non-HTTP scheme (file://, ftp://, etc.)
- **THEN** the request is blocked

### Requirement: Redirect depth limiting
The system SHALL limit the number of redirects to prevent infinite redirect loops.

#### Scenario: Max redirects enforced
- **WHEN** more than 10 redirects occur
- **THEN** the request fails with 502 Bad Gateway

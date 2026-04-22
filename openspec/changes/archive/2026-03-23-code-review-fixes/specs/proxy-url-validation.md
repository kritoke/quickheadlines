## ADDED Requirements

### Requirement: Proxy URL domain allowlist
The system SHALL validate image proxy URLs against a domain allowlist in addition to the existing validation rules.

#### Scenario: Allowed domains pass validation
- **WHEN** a request to /proxy_image has url parameter pointing to i.imgur.com
- **THEN** the request is allowed to proceed
- **AND** the image is fetched and returned

#### Scenario: Disallowed domains are blocked
- **WHEN** a request to /proxy_image has url parameter pointing to evil.com
- **THEN** the request returns 400 Bad Request
- **AND** the response contains "Domain not allowed"

#### Scenario: Unknown redirect domains are blocked
- **WHEN** /proxy_image follows a redirect to an unknown domain
- **THEN** the request returns 400 Bad Request
- **AND** the response contains "Domain not allowed"

### Requirement: Configurable domain allowlist
The system SHALL allow configuring the allowed domains for the proxy.

#### Scenario: Default domains are set
- **WHEN** the proxy is initialized
- **THEN** default allowed domains include: i.imgur.com, pbs.twimg.com, avatars.githubusercontent.com, lh3.googleusercontent.com, i.pravatar.cc

#### Scenario: Custom domains can be configured
- **WHEN** Configuration is updated with custom allowed domains
- **THEN** only URLs matching those domains are allowed
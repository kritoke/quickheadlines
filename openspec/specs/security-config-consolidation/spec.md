## ADDED Requirements

### Requirement: Single SecurityConfig struct
The system SHALL provide exactly one `SecurityConfig` struct definition.

#### Scenario: SecurityConfig has unique definition
- **WHEN** code references `SecurityConfig`
- **THEN** there is exactly one struct definition
- **AND** it uses `property?` for boolean fields (e.g., `rate_limit_enabled?`)

#### Scenario: SecurityConfig is used in Config
- **WHEN** a Config instance is created with security settings
- **THEN** the SecurityConfig is properly serialized/deserialized via YAML

### Requirement: Rate limit settings accessible
The system SHALL provide access to rate limiting settings through SecurityConfig.

#### Scenario: Rate limiting enabled
- **WHEN** `security.rate_limit_enabled?` is called
- **THEN** it returns true or false based on config

#### Scenario: Rate limit requests per minute
- **WHEN** `security.rate_limit_requests_per_minute` is called
- **THEN** it returns the configured value (default: 60)

#### Scenario: Custom user agent
- **WHEN** `security.user_agent` is called
- **THEN** it returns the configured user agent string or nil

### Requirement: Proxy allowed domains
The system SHALL provide a list of domains allowed for image proxy.

#### Scenario: Default allowed domains
- **WHEN** no proxy_allowed_domains is configured
- **THEN** default domains are ["google.com", "reddit.com", "github.com"]

#### Scenario: Custom allowed domains
- **WHEN** proxy_allowed_domains is configured in feeds.yml
- **THEN** the configured domains are used for validation

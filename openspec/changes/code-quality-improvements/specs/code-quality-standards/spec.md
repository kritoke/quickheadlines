## ADDED Requirements

### Requirement: Centralized Constants Module
The system SHALL provide a centralized constants module containing all configurable magic numbers used throughout the codebase.

#### Scenario: Constants module contains HTTP settings
- **WHEN** code references HTTP timeout or retry values
- **THEN** it SHALL use constants from `Constants` module (e.g., `Constants::HTTP_TIMEOUT_SECONDS`)

#### Scenario: Constants module contains clustering settings
- **WHEN** clustering service needs threshold or band values
- **THEN** it SHALL use constants from `Constants` module (e.g., `Constants::CLUSTERING_DEFAULT_THRESHOLD`)

#### Scenario: Constants module contains pagination settings
- **WHEN** pagination logic needs limit values
- **THEN** it SHALL use constants from `Constants` module (e.g., `Constants::PAGINATION_DEFAULT_LIMIT`)

---

### Requirement: Structured Logging System
The system SHALL provide a structured logging system with configurable log levels, timestamps, and contextual information.

#### Scenario: Logging with debug level
- **WHEN** `Log.debug` is called with a message
- **THEN** it SHALL output formatted message with timestamp and DEBUG level when logging is enabled

#### Scenario: Logging with error level
- **WHEN** `Log.error` is called with an exception and context
- **THEN** it SHALL output formatted message including exception details and context hash

#### Scenario: Logging respects configured level
- **WHEN** logging level is set to WARN
- **THEN** DEBUG and INFO messages SHALL be suppressed

---

### Requirement: Custom Exception Types
The system SHALL define specific exception types for different error conditions to enable proper error handling.

#### Scenario: Feed fetch error contains URL context
- **WHEN** a feed fetch fails
- **THEN** it SHALL raise `FeedFetchError` with the feed URL accessible via getter

#### Scenario: Configuration error is distinct from generic exceptions
- **WHEN** configuration loading fails
- **THEN** it SHALL raise `ConfigurationError` instead of generic `Exception`

---

### Requirement: URL Normalization Utility
The system SHALL provide a single URL normalization utility function that handles www prefix, trailing slashes, and common variations.

#### Scenario: Normalize removes www prefix
- **WHEN** `Utils.normalize_url` is called with "https://www.example.com/feed"
- **THEN** it SHALL return "https://example.com/feed"

#### Scenario: Normalize removes trailing slash
- **WHEN** `Utils.normalize_url` is called with "https://example.com/feed/"
- **THEN** it SHALL return "https://example.com/feed"

#### Scenario: Normalize handles HTTP URLs
- **WHEN** `Utils.normalize_url` is called with "http://www.example.com"
- **THEN** it SHALL return "http://example.com"

---

### Requirement: Rate Limiting Middleware
The system SHALL implement rate limiting to prevent API abuse while allowing legitimate access.

#### Scenario: Rate limiting blocks excessive requests
- **WHEN** a client makes more than configured requests per minute
- **THEN** it SHALL return HTTP 429 with appropriate headers

#### Scenario: Rate limiting allows legitimate traffic
- **WHEN** a client makes requests within the rate limit
- **THEN** it SHALL process normally without rate limit headers

#### Scenario: Rate limiting is configurable
- **WHEN** rate limit configuration is provided in feeds.yml
- **THEN** it SHALL apply the configured limits

---

### Requirement: Image Proxy Domain Restrictions
The system SHALL restrict the image proxy endpoint to trusted domains only to prevent abuse.

#### Scenario: Proxy blocks untrusted domains
- **WHEN** a request is made to proxy_image with an untrusted domain
- **THEN** it SHALL return HTTP 403 Forbidden

#### Scenario: Proxy allows trusted domains
- **WHEN** a request is made to proxy_image with a trusted favicon domain
- **THEN** it SHALL proxy the image normally

#### Scenario: Proxy domain allowlist is configurable
- **WHEN** allowed domains are configured in feeds.yml
- **THEN** the proxy SHALL use the configured allowlist

---

### Requirement: Module Naming Consistency
The system SHALL use consistent module naming with `QuickHeadlines::` (capital H) throughout the codebase.

#### Scenario: All services use consistent naming
- **WHEN** a service module is defined
- **THEN** it SHALL use `QuickHeadlines::Services::` namespace

#### Scenario: All repositories use consistent naming
- **WHEN** a repository module is defined
- **THEN** it SHALL use `QuickHeadlines::Repositories::` namespace

---

### Requirement: Controller Separation
The system SHALL separate the monolithic API controller into focused controllers for maintainability.

#### Scenario: Feeds endpoint handled by feeds controller
- **WHEN** a request is made to `/api/feeds`
- **THEN** it SHALL be routed to `FeedsController`

#### Scenario: Timeline endpoint handled by timeline controller
- **WHEN** a request is made to `/api/timeline`
- **THEN** it SHALL be routed to `TimelineController`

#### Scenario: Admin endpoints handled by admin controller
- **WHEN** a request is made to `/api/admin` or `/api/cluster`
- **THEN** it SHALL be routed to `AdminController`

#### Scenario: Existing route paths remain unchanged
- **WHEN** any API endpoint is called
- **THEN** the URL path SHALL remain the same as before the refactor

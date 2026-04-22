## ADDED Requirements

### Requirement: Static Response Security Headers
The system SHALL include baseline browser hardening headers on static responses.

#### Scenario: Static response includes hardening headers
- **WHEN** a static asset or HTML route is served by `StaticController`
- **THEN** the response includes security headers including CSP and anti-mime-sniffing controls

### Requirement: Security Header Consistency
The system SHALL apply security headers from a centralized helper to reduce per-route drift.

#### Scenario: New static route reuses common header policy
- **WHEN** a new static route is added using the shared static response helper
- **THEN** it receives the same baseline security headers without route-specific duplication

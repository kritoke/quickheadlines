## ADDED Requirements

### Requirement: Proxy Image Payload Limit
The system SHALL enforce a maximum payload size for `/proxy_image` responses.

#### Scenario: Reject oversized proxied image
- **WHEN** a proxied image response exceeds the maximum allowed bytes
- **THEN** the endpoint returns HTTP `413` and does not return the oversized payload

### Requirement: Proxy Image Content-Type Validation
The system SHALL only proxy responses with an image content-type.

#### Scenario: Reject non-image content
- **WHEN** the proxied response content-type is not `image/*`
- **THEN** the endpoint returns HTTP `415` and does not return the response body

## ADDED Requirements

### Requirement: Image proxy limits response size
The image proxy endpoint SHALL limit the size of responses to prevent memory exhaustion.

#### Scenario: Response within size limit
- **WHEN** client requests `/proxy_image?url=<valid>` and upstream returns image under 10MB
- **THEN** image is returned normally

#### Scenario: Response exceeds size limit
- **WHEN** client requests `/proxy_image?url=<valid>` and upstream returns image over 10MB
- **THEN** response status code is 502
- **THEN** response body contains "Response too large"

#### Scenario: Size limit is configurable
- **WHEN** `security.proxy_max_response_size` is set in config
- **THEN** that limit is enforced instead of default 10MB

### Requirement: Image proxy validates request size
The image proxy endpoint SHALL limit the size of incoming requests.

#### Scenario: Request URL within limit
- **WHEN** client requests `/proxy_image?url=<2kb_url>`
- **THEN** request is processed normally

#### Scenario: Request URL exceeds limit
- **WHEN** client requests `/proxy_image?url=<10kb_url>`
- **THEN** response status code is 414 (URI Too Long)

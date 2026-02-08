## ADDED Requirements

### Requirement: Reproducible favicon fetch traces
The system SHALL provide a reproducible way to fetch and record detailed traces for favicon fetch attempts for a supplied list of hosts. The trace SHALL include final resolved URL, HTTP status code, Content-Type header, response body size in bytes, and the first 128 bytes of the response body in hex form.

#### Scenario: Run check_favicons script
- **WHEN** a developer runs `nix develop . --command crystal run scripts/check_favicons.cr`
- **THEN** the script prints one line per host with the fields: host, final_url, status_code, content_type, size_bytes, sample_hex

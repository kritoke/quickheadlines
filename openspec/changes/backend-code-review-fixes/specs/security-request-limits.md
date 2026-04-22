# security-request-limits

**Owner:** Backend Team  
**Status:** proposed

## Overview

Enforce maximum request body sizes on all endpoints that accept request bodies. This prevents memory exhaustion attacks where an attacker sends multi-GB POST/PUT payloads.

## Requirements

### REQ-001: Maximum Body Size Constant
`MAX_REQUEST_BODY_SIZE = 1_048_576` (1 MB) is defined in `Constants`.

### REQ-002: Body Reading Helper
A `read_body_safe(io : IO, max_size : Int32)` helper is created that:
1. Reads from `io` up to `max_size` bytes
2. Returns the read content as `String`
3. If a byte is read beyond `max_size`, raises `BodyTooLargeError`
4. If `nil` body, returns empty string

### REQ-003: Protected Endpoints
The following endpoints use `read_body_safe`:
- `POST /api/header_color` — currently calls `body_io.gets_to_end`
- `POST /api/admin` — currently calls `body_io.gets_to_end`

### REQ-004: Error Response
`BodyTooLargeError` is caught by the controller and returns HTTP 413 with `Content-Type: text/plain` and body `"Request body too large"`.

## Acceptance Criteria

- [ ] `POST /api/admin` with body > 1MB returns 413
- [ ] `POST /api/header_color` with body > 1MB returns 413
- [ ] Normal-sized bodies (<1MB) work correctly
- [ ] Empty bodies are accepted

## Affected Files

- `src/constants.cr` — `MAX_REQUEST_BODY_SIZE`
- `src/utils.cr` — `read_body_safe` helper
- `src/controllers/feeds_controller.cr` — `save_header_color`
- `src/controllers/admin_controller.cr` — `admin`

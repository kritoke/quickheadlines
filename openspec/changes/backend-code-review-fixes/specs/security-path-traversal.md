# security-path-traversal

**Owner:** Backend Team  
**Status:** proposed

## Overview

Prevent path traversal attacks in the favicon file serving endpoint. User-controlled `hash` and `ext` route parameters must be validated before being used in file system operations.

## Requirements

### REQ-001: Hash Format Validation
The `hash` parameter (from route `/favicons/{hash}.{ext}`) must match the regex `\A[a-f0-9]{64}\z\` (64-character lowercase hexadecimal). Any other format is rejected with HTTP 400.

### REQ-002: Extension Validation
The `ext` parameter must be one of: `png`, `ico`, `svg`, `gif`, `jpg`, `jpeg`. All other values are rejected with HTTP 400.

### REQ-003: Path Containment Check
After constructing the file path, the resolved real path must start with `FaviconStorage.favicon_dir`. If the resolved path escapes the favicon directory, return HTTP 400.

### REQ-004: Graceful Not Found
If validation passes but the file does not exist, return HTTP 404 (not 400).

## Acceptance Criteria

- [ ] `/favicons/abc123...def (64 chars).png` where file exists → 200
- [ ] `/favicons/../../../etc/passwd.png` → 400
- [ ] `/favicons/abc123...def.js` (invalid ext) → 400
- [ ] `/favicons/abc (not 64 chars).png` → 400
- [ ] `/favicons/abc123...def.png` where file does not exist → 404

## Affected Files

- `src/controllers/proxy_controller.cr` — `favicon_file`

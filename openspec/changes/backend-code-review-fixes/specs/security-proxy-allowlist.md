# security-proxy-allowlist

**Owner:** Backend Team  
**Status:** proposed

## Overview

Replace the private-host denylist in the image proxy with an explicit domain allowlist. This prevents SSRF attacks that bypass denylists via DNS rebinding, IPv6 variants, or internal DNS leaks.

## Requirements

### REQ-001: Explicit Domain Allowlist
The image proxy (`GET /api/proxy-image`) must only allow requests to domains explicitly listed in `ALLOWED_PROXY_DOMAINS`.

**Initial allowlist:**
```
i.imgur.com
pbs.twimg.com
avatars.githubusercontent.com
lh3.googleusercontent.com
i.pravatar.cc
images.unsplash.com
fastly.picsum.photos
```

### REQ-002: Scheme Restriction
Only `https://` URLs are permitted. `http://` URLs are rejected with 403.

### REQ-003: URL Validation Flow
1. Parse URL with `URI.parse`
2. Reject if scheme is not `https`
3. Reject if host is not in `ALLOWED_PROXY_DOMAINS` (case-insensitive comparison)
4. Reject if URL contains credentials (`user:pass@`)
5. Reject if URL contains a port number (some CDNs use non-standard ports)
6. Accept if all checks pass

### REQ-004: Error Response
Rejections return HTTP 403 with `Content-Type: text/plain` and body `"Disallowed proxy domain"`.

### REQ-005: Response Streaming
Image responses must be streamed with size checking, not buffered fully into memory. If the response exceeds `MAX_PROXY_IMAGE_BYTES`, close the connection and return 413.

## Acceptance Criteria

- [ ] Proxy request to `https://i.imgur.com/foo.jpg` returns image
- [ ] Proxy request to `https://evil.com/foo.jpg` returns 403
- [ ] Proxy request to `http://i.imgur.com/foo.jpg` (insecure) returns 403
- [ ] Proxy request with credentials in URL returns 403
- [ ] Large image (>MAX_PROXY_IMAGE_BYTES) returns 413
- [ ] No full-body buffering occurs

## Affected Files

- `src/controllers/proxy_controller.cr` — `validate_proxy_url`, `proxy_image`
- `src/constants.cr` — `ALLOWED_PROXY_DOMAINS` constant

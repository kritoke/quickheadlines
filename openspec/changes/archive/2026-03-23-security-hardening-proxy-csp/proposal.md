## Why

The image proxy endpoint can currently read unbounded response bodies into memory, which increases denial-of-service risk. Static HTML/assets also lack consistent defensive response headers, leaving preventable browser-side attack surface.

## What Changes

- Add hard limits and validation for proxied image responses, including maximum payload size and content-type checks.
- Add baseline security headers for static responses, including CSP and related browser hardening headers.
- Keep compatibility with Crystal 1.18.2 and existing runtime behavior (no `Time::Instant` usage).

## Capabilities

### New Capabilities

- `proxy-image-guardrails`: Enforce safe proxy behavior with bounded response size and image-only content validation.
- `browser-security-headers`: Apply baseline security headers to static web responses.

### Modified Capabilities

- None.

## Impact

- Affected code: `src/controllers/api_controller.cr`, `src/web/static_controller.cr`
- APIs: `/proxy_image` behavior for oversized/non-image responses
- Runtime: lower memory pressure risk and stronger browser protections

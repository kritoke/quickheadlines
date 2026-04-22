## 1. Proxy Endpoint Hardening

- [x] 1.1 Add max payload size guard to `/proxy_image`
- [x] 1.2 Add content-type validation (`image/*`) for proxied responses
- [x] 1.3 Return clear status codes for guardrail violations (`413`, `415`)

## 2. Static Security Headers

- [x] 2.1 Add centralized security-header helper in `StaticController`
- [x] 2.2 Apply CSP and baseline hardening headers to static responses

## 3. Verification

- [x] 3.1 Run `just nix-build`
- [x] 3.2 Run Crystal specs and frontend tests
- [x] 3.3 Update tasks as complete

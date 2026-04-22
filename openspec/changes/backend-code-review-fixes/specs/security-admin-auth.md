# security-admin-auth

**Owner:** Backend Team  
**Status:** proposed

## Overview

Enforce admin authentication on all sensitive endpoints. When `ADMIN_SECRET` environment variable is absent or empty, all admin endpoints return HTTP 401 Unauthorized. This reverses the current default (which allows access when `ADMIN_SECRET` is absent — a critical security flaw for public-facing deployment).

## Requirements

### REQ-001: Default-Deny Behavior
When `ADMIN_SECRET` is not set in the environment, any request to a protected endpoint must receive HTTP 401 with body `"Unauthorized"`.

**Protected endpoints:**
- `POST /api/cluster`
- `POST /api/admin`
- `GET /api/status`
- `GET /api/version`

### REQ-002: Bearer Token Validation
When `ADMIN_SECRET` is set, requests must include `Authorization: Bearer <token>` header. The token must be compared using a timing-safe string comparison.

### REQ-003: Timing-Safe Comparison
The token comparison must use constant-time comparison to prevent timing attacks. The existing `timing_safe_compare` implementation in `api_base_controller.cr` satisfies this requirement.

### REQ-004: Error Response Format
Unauthorized responses must be HTTP 401 with `Content-Type: text/plain` and body `"Unauthorized"`.

## Acceptance Criteria

- [ ] `POST /api/cluster` without `ADMIN_SECRET` env var returns 401
- [ ] `POST /api/cluster` with wrong token returns 401
- [ ] `POST /api/cluster` with correct token returns 202
- [ ] Same for `/api/admin`, `/api/status`, `/api/version`
- [ ] Timing-safe comparison is used (not `==` or `===`)

## Affected Files

- `src/controllers/api_base_controller.cr` — `check_admin_auth` method
- `src/controllers/admin_controller.cr` — `status` endpoint

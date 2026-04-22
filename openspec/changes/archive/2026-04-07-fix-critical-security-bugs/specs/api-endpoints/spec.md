# api-endpoints Specification

## Purpose

Defines authentication and authorization requirements for all REST API endpoints in QuickHeadlines.

## Requirements

### Requirement: Protected administrative endpoints require valid admin authentication
All administrative endpoints that modify server state SHALL validate the `ADMIN_SECRET` environment variable via Bearer token in the `Authorization` header before executing.

#### Scenario: Admin request with valid token
- **WHEN** a POST request is made to `/api/cluster` or `/api/admin` with a `Bearer <ADMIN_SECRET>` token
- **THEN** the request is authenticated and the operation proceeds

#### Scenario: Admin request with missing Authorization header
- **WHEN** a POST request is made to `/api/cluster` or `/api/admin` without an `Authorization` header
- **THEN** the server returns HTTP 401 Unauthorized

#### Scenario: Admin request with invalid token
- **WHEN** a POST request is made to `/api/cluster` or `/api/admin` with an incorrect token value
- **THEN** the server returns HTTP 401 Unauthorized

### Requirement: Unauthenticated endpoints do not modify persistent state
Public endpoints that do not require authentication SHALL NOT modify any server-side persistent state including database records, configuration, or cached data.

#### Scenario: Timeline request is read-only
- **WHEN** a GET request is made to `/api/timeline`
- **THEN** no database writes, feed fetches, or state modifications occur

#### Scenario: Feeds request is read-only
- **WHEN** a GET request is made to `/api/feeds`
- **THEN** no database writes, feed fetches, or state modifications occur

### Requirement: Rate limiting on public write-adjacent endpoints
Public endpoints that trigger expensive server operations SHALL implement per-IP rate limiting.

#### Scenario: Proxy image request exceeds rate limit
- **WHEN** an IP makes more than 30 proxy-image requests within a 60-second window
- **THEN** the server returns HTTP 429 with a `Retry-After` header

#### Scenario: Feed pagination request exceeds rate limit
- **WHEN** an IP makes more than 30 feed-more requests within a 60-second window
- **THEN** the server returns HTTP 429 with a `Retry-After` header

### Requirement: Header color save endpoint requires admin authentication
The `POST /api/header_color` endpoint SHALL require valid admin authentication. Unauthenticated or non-admin requests SHALL be rejected with HTTP 401 Unauthorized.

#### Scenario: Authenticated admin saves header color
- **WHEN** an authenticated admin POSTs to `/api/header_color` with valid JSON body containing `feed_url`, `color`, and `text_color`
- **THEN** the header color is persisted to the database and HTTP 200 is returned

#### Scenario: Unauthenticated request to save header color
- **WHEN** an unauthenticated POST is made to `/api/header_color`
- **THEN** the server returns HTTP 401 Unauthorized and no color data is modified
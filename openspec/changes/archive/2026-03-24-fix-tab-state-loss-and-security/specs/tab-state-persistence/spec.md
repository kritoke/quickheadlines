## ADDED Requirements

### Requirement: Tab state persists across view switches
When a user selects a tab in either the feed view or timeline view, the selected tab SHALL persist when switching between the two views.

#### Scenario: User switches from feed view to timeline view with tab selected
- **GIVEN** user is on feed view with tab "Tech" selected
- **WHEN** user clicks the view switch button to go to timeline view
- **THEN** timeline view displays items for tab "Tech"

#### Scenario: User switches from timeline view to feed view with tab selected
- **GIVEN** user is on timeline view with tab "News" selected
- **WHEN** user clicks the view switch button to go to feed view
- **THEN** feed view displays feeds for tab "News"

#### Scenario: User manually changes URL tab parameter
- **GIVEN** user is on feed view with tab "all" active
- **WHEN** user manually changes URL from `/?tab=all` to `/?tab=Tech`
- **THEN** feed view reloads and displays items for tab "Tech"

### Requirement: Feed page reacts to URL tab changes
The feed page SHALL reload its content when the URL's tab parameter changes, even on subsequent visits.

#### Scenario: User navigates back to feed page with different tab
- **GIVEN** user previously visited feed page on tab "Tech" and has since visited timeline page
- **WHEN** user navigates back to feed view with URL `/?tab=News`
- **THEN** feed view displays feeds for tab "News" (not the cached "Tech" data)

#### Scenario: Feed page handles URL without tab parameter
- **WHEN** user navigates to feed view with no tab parameter (`/`)
- **THEN** feed view displays all feeds (equivalent to tab "all")

### Requirement: Favicon endpoint prevents path traversal
The favicon endpoint SHALL validate that requested file paths cannot escape the designated favicon directory.

#### Scenario: Attacker attempts path traversal
- **WHEN** attacker requests `/favicons/../../../etc/passwd.png`
- **THEN** server returns 404 or 400 error

#### Scenario: Valid favicon request
- **WHEN** user requests a valid favicon by hash
- **THEN** server returns the favicon file with correct Content-Type

### Requirement: SSRF prevention for feed redirects
The feed fetcher SHALL validate redirect destinations to prevent requests to internal/private network addresses.

#### Scenario: Feed redirects to internal IP
- **WHEN** a feed responds with a redirect to `http://169.254.169.254/latest/meta-data/`
- **THEN** the fetch is rejected and the redirect is not followed

#### Scenario: Feed redirects to public URL
- **WHEN** a feed responds with a redirect to `https://example.com/feed.xml`
- **THEN** the redirect is followed normally

### Requirement: IPv6 addresses handled correctly for rate limiting
The WebSocket connection manager SHALL correctly parse IPv6 addresses for per-IP connection limits.

#### Scenario: IPv6 client connects
- **WHEN** a client connects from IPv6 address `::1`
- **THEN** the connection is counted correctly and rate limiting works per client

### Requirement: API errors do not leak internal information
API error responses SHALL NOT include internal details such as file paths, database schema, or exception stack traces.

#### Scenario: Internal error occurs
- **WHEN** an unexpected internal error occurs in an API endpoint
- **THEN** the response contains a generic message ("Internal server error") not the exception message

### Requirement: feed_more endpoint returns correct pagination
The feed_more endpoint SHALL return items starting from the requested offset, not from the beginning.

#### Scenario: Client requests items with offset
- **WHEN** client requests `GET /api/feed_more?url=...&offset=10&limit=10`
- **THEN** response contains items 10-19, not items 0-19

### Requirement: WebSocket message counter is accurate
The WebSocket message counter SHALL accurately reflect the number of messages actually sent over the wire.

#### Scenario: Messages are broadcast
- **WHEN** server broadcasts 5 messages to connected clients
- **THEN** the messages_sent counter increments by exactly 5

### Requirement: IP connection counts are accurate
The WebSocket IP connection counter SHALL accurately reflect the number of connections per IP address.

#### Scenario: Multiple connections from same IP
- **WHEN** client opens 3 connections from same IP and then closes them all
- **THEN** the IP count returns to 0 (not negative)

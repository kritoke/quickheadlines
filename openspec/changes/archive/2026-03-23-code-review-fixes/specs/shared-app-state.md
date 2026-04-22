## ADDED Requirements

### Requirement: Lightweight tabs API endpoint
The system SHALL provide a dedicated `/api/tabs` endpoint that returns only tab names without fetching feed data.

#### Scenario: Tabs endpoint returns only tab names
- **WHEN** a client requests GET /api/tabs
- **THEN** the response includes a list of tab names
- **AND** no feed items are included in the response

#### Scenario: Tabs endpoint is fast
- **WHEN** a client requests GET /api/tabs
- **THEN** the response time is under 50ms (no database queries required)

### Requirement: Client uses tabs endpoint instead of full feed fetch
The frontend SHALL use the `/api/tabs` endpoint to load tabs instead of fetching all feeds.

#### Scenario: Frontend fetches tabs separately
- **WHEN** the timeline page loads
- **THEN** it calls `/api/tabs` to get the tab list
- **AND** does NOT call `/api/feeds` just to extract tabs

#### Scenario: Feed page reuses appState tabs
- **WHEN** feed page initializes
- **AND** appState already has tabs loaded
- **THEN** the page uses the cached tabs instead of fetching again
## ADDED Requirements

### Requirement: Feed data must be fully assigned from API response
The feeds view SHALL assign all relevant fields from the API response to component state, including feeds, tabs, and lastUpdated timestamp.

#### Scenario: Successful feed fetch
- **WHEN** API returns feeds response with `updated_at`, `tabs`, and `feeds` fields
- **THEN** component state MUST set `lastUpdated` to Date from `updated_at` (milliseconds)
- **AND** component state MUST set `tabs` array from response
- **AND** component state MUST set `feeds` array from response

#### Scenario: Cache timestamp is correct
- **WHEN** feeds are successfully fetched and cached
- **THEN** cache entry MUST include `updatedAt` set to current `lastUpdated` value
- **AND** cache validation MUST use this timestamp for staleness checks

### Requirement: Single refresh interval for feed updates
The feeds view SHALL maintain exactly one active refresh interval at any time.

#### Scenario: Initial page load
- **WHEN** page loads and config is fetched
- **THEN** exactly ONE refresh interval MUST be created
- **AND** interval duration MUST match `refresh_minutes` from config

#### Scenario: Config refresh interval changes
- **WHEN** config refresh interval changes from 10 minutes to 5 minutes
- **THEN** old interval MUST be cleared
- **AND** new interval MUST be created with 5-minute duration
- **AND** only ONE interval MUST be active at any time

#### Scenario: Component unmount
- **WHEN** user navigates away from feeds page
- **THEN** all intervals MUST be cleared
- **AND** no intervals MUST remain active

### Requirement: Request errors must be handled appropriately
The API layer MUST distinguish between expected errors (cancelled requests) and actual errors.

#### Scenario: Request aborted during tab switch
- **WHEN** user switches tabs while feed fetch is in-flight
- **THEN** first request MUST be aborted
- **AND** AbortError MUST be caught
- **AND** NO error toast MUST be shown to user
- **AND** new request for new tab MUST proceed

#### Scenario: Actual network error
- **WHEN** network request fails with actual error (not abort)
- **THEN** error toast MUST be shown to user
- **AND** error MUST be logged

### Requirement: Feed requests must have timeout protection
Feed fetch requests SHALL timeout after a reasonable duration to prevent indefinite hangs.

#### Scenario: Slow network request
- **WHEN** feed fetch request takes longer than 30 seconds
- **THEN** request MUST be aborted
- **AND** timeout error MUST be shown to user

#### Scenario: Fast network request
- **WHEN** feed fetch completes in under 30 seconds
- **THEN** request MUST proceed normally
- **AND** no timeout MUST occur

### Requirement: Duplicate concurrent requests must be prevented
The API layer SHALL deduplicate concurrent requests for the same resource.

#### Scenario: Rapid tab switches
- **WHEN** user rapidly switches between tabs A, B, and back to A
- **AND** request for tab A is still in-flight
- **THEN** second request for tab A MUST return the existing promise
- **AND** only ONE actual HTTP request MUST be made for tab A
- **AND** both callers MUST receive the same response

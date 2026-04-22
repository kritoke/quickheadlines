## MODIFIED Requirements

### Requirement: Feed configuration options
The system SHALL support a simplified set of configuration options in feeds.yml, removing rarely-used advanced settings while preserving essential functionality.

#### Scenario: Simplified feed configuration
- **WHEN** user configures feeds.yml with only essential options
- **THEN** system successfully loads and processes all feeds including software releases

#### Scenario: Removed configuration options
- **WHEN** user attempts to use removed configuration options (per-feed retry/timeout, rate limiting, HTTP client advanced settings, authentication)
- **THEN** system ignores these options and uses sensible defaults without error

### Requirement: Clustering implementation
The system SHALL use only the LSH-based clustering implementation (`recluster_with_lsh`) and SHALL NOT include the unused `cluster_uncategorized` method.

#### Scenario: Single clustering method
- **WHEN** clustering is enabled in configuration
- **THEN** system uses only `recluster_with_lsh` method for all clustering operations

#### Scenario: Clustering functionality preserved
- **WHEN** similar headlines are processed
- **THEN** system correctly clusters them using MinHash/LSH with overlap coefficient

### Requirement: Theme system functionality
The system SHALL maintain all 10 themes and cursor trail functionality while potentially simplifying internal implementation details.

#### Scenario: All themes available
- **WHEN** user accesses theme picker
- **THEN** all 10 themes (light, dark, retro, matrix, ocean, sunset, hotdog, dracula, cyberpunk, forest) are available

#### Scenario: Cursor trail active
- **WHEN** user moves mouse on any page
- **THEN** cursor trail effect is visible with primary dot and blurred trail

### Requirement: Software releases feature
The system SHALL fully preserve the software releases feature including GitHub, GitLab, and Codeberg repository support.

#### Scenario: Software releases in tabs
- **WHEN** tab configuration includes software_releases section
- **THEN** system fetches and displays release information from specified repositories

#### Scenario: Multi-platform repository support
- **WHEN** software_releases configuration includes repositories from different platforms (GitHub, GitLab, Codeberg)
- **THEN** system correctly fetches releases from all specified platforms

### Requirement: State management
The system SHALL replace global state singletons (`STATE`, `FEED_CACHE`) with proper dependency injection while maintaining identical external behavior.

#### Scenario: State access unchanged
- **WHEN** components access application state
- **THEN** all state information is available with identical interface and behavior

#### Scenario: Thread safety maintained
- **WHEN** concurrent operations access shared state
- **THEN** system maintains thread safety and data consistency

### Requirement: WebSocket real-time updates
The system SHALL consolidate WebSocket handlers into a single unified handler while maintaining identical real-time update functionality.

#### Scenario: Real-time feed updates
- **WHEN** new feed items are fetched
- **THEN** frontend receives real-time updates via WebSocket

#### Scenario: Real-time clustering updates  
- **WHEN** clustering operations complete
- **THEN** frontend receives clustering status updates via the same WebSocket connection
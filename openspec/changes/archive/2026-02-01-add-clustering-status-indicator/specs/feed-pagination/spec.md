## ADDED Requirements

### Requirement: Clustering Status in API
The feed API responses SHALL include a `is_clustering` boolean flag indicating if the background clustering process is still running for the latest fetch.

#### Scenario: API returns clustering status
- **WHEN** the frontend requests feed data
- **THEN** the JSON response SHALL include a top-level `is_clustering` property.

## ADDED Requirements

### Requirement: Clustering Progress Indicator
The UI SHALL display an animated dots indicator when story clustering is in progress in the background.

#### Scenario: Indicator Visibility
- **WHEN** the backend reports that clustering is active (`is_clustering: true`)
- **THEN** the dashboard SHALL display an animated "..." or spinner near the grouping status.

### Requirement: Global Clustering State
The backend SHALL track the global state of background clustering jobs across all feeds.

#### Scenario: Status Reporting
- **WHEN** any background clustering fiber is active
- **THEN** the system status API SHALL return `is_clustering: true`.

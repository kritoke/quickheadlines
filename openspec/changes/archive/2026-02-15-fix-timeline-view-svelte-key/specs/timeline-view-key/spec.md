## ADDED Requirements

### Requirement: TimelineView each block has a key
The TimelineView component SHALL use a unique key for each block when iterating over grouped timeline items to ensure correct DOM updates.

#### Scenario: Render timeline with grouped items
- **WHEN** TimelineView renders items grouped by date
- **THEN** each {#each} block uses a unique key (date string)

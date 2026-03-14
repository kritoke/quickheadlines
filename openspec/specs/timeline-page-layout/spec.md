## MODIFIED Requirements

### Requirement: Timeline supports multi-column grid layouts
The timeline page SHALL support configurable column counts from 1 to 4 columns, enabling users to customize their reading experience based on viewport width.

#### Scenario: Single column layout
- **WHEN** timelineColumns is set to 1
- **THEN** items display in a single column grid at all viewport sizes
- **AND** each item spans the full width of the content area

#### Scenario: Two column layout
- **WHEN** timelineColumns is set to 2
- **THEN** items display in two columns on small viewports (sm:)
- **AND** each item spans half the available width

#### Scenario: Three column layout  
- **WHEN** timelineColumns is set to 3
- **THEN** items display in two columns on small viewports (sm:)
- **AND** items display in three columns on large viewports (lg:)

#### Scenario: Four column layout
- **WHEN** timelineColumns is set to 4
- **THEN** items display in two columns on small viewports (sm:)
- **AND** items display in three columns on large viewports (lg:)
- **AND** items display in four columns on extra-large viewports (xl:)

### Requirement: Cluster items can be expanded to show similar stories
When a timeline item is part of a cluster with multiple sources, users SHALL be able to expand it to see all similar stories from different feeds.

#### Scenario: Expand cluster in single column
- **WHEN** user clicks cluster expansion button on a clustered item in single-column layout
- **THEN** the item expands to show all items in that cluster below it
- **AND** the expansion does not change the column span

#### Scenario: Expand cluster in multi-column layout
- **WHEN** user clicks cluster expansion button on a clustered item in multi-column (2+) layout
- **THEN** the item expands to show all items in that cluster below it
- **AND** the expanded item spans full width (col-span-full) to accommodate all clustered items
- **AND** other columns in that row adjust their layout accordingly

#### Scenario: Collapse expanded cluster
- **WHEN** user clicks the expansion button on an already-expanded cluster
- **THEN** the cluster collapses and hides the additional clustered items

#### Scenario: Cluster expansion keyed by cluster_id
- **WHEN** comparing expandedClusterId for expansion state
- **THEN** the comparison uses item.cluster_id, not item.id
- **AND** this ensures all representative items in the same cluster expand/collapse together

## ADDED Requirements

### Requirement: Primary layout components have data-name attributes
The system SHALL add `data-name` attributes to all primary layout components for AI agent DOM interaction.

#### Scenario: Main page layout
- **WHEN** the main feeds page renders
- **THEN** the root container has `data-name="feeds-page"`

#### Scenario: App layout
- **WHEN** the app layout renders
- **THEN** the root container has `data-name="app-layout"`

#### Scenario: Header component
- **WHEN** the Header component renders
- **THEN** the header element has `data-name="main-header"`

### Requirement: Interactive components have data-name attributes
The system SHALL add `data-name` attributes to all interactive elements for agent targeting.

#### Scenario: FeedBox component
- **WHEN** the FeedBox component renders
- **THEN** the container has `data-name="feed-box"` and load-more button has `data-name="load-more"`

#### Scenario: FeedTabs component
- **WHEN** the FeedTabs component renders
- **THEN** the nav has `data-name="feed-tabs"` and each tab button has `data-name="tab-button"`

#### Scenario: Timeline view
- **WHEN** the TimelineView component renders
- **THEN** the container has `data-name="timeline-view"`

#### Scenario: Cluster expansion
- **WHEN** the ClusterExpansion component renders
- **THEN** the container has `data-name="cluster-expansion"`

### Requirement: UI primitives have data-name attributes
The system SHALL add `data-name` attributes to base UI components.

#### Scenario: Button component
- **WHEN** the Button component renders
- **THEN** the button element has `data-name="button"`

#### Scenario: Card component
- **WHEN** the Card component renders
- **THEN** the div element has `data-name="card"`

#### Scenario: Link component
- **WHEN** the Link component renders
- **THEN** the anchor element has `data-name="link"`

### Requirement: No reliance on CSS classes for logic
The system SHALL NOT use generated CSS classes for DOM targeting or logic.

#### Scenario: Component styling
- **WHEN** components are styled
- **THEN** CSS classes are used only for presentation, never for JavaScript logic

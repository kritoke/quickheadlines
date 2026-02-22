## ADDED Requirements

### Requirement: Feed card bottom gradient shadow
The system SHALL render a bottom gradient shadow on feed cards to indicate there is additional scrollable content.

#### Scenario: Shadow visible when not at bottom
- **WHEN** a feed card's scrollable body is not scrolled to its bottom
- **THEN** the feed card SHALL render a bottom gradient via its `::after` pseudo-element with non-zero opacity

#### Scenario: Shadow hidden when at bottom
- **WHEN** the feed card's scrollable body is scrolled to bottom
- **THEN** the feed card SHALL remove or hide the bottom gradient (opacity: 0)

### Requirement: Semantic selectors
The system SHALL expose the feed card and feed body via `Theme.semantic` attributes so client-side scripts and tests can target `[data-semantic="feed-card"]` and `[data-semantic="feed-body"]`.

#### Scenario: Semantic attributes present
- **WHEN** the UI renders feed cards
- **THEN** each feed card SHALL include `data-semantic="feed-card"` and the scrollable container within SHALL include `data-semantic="feed-body"` when applicable

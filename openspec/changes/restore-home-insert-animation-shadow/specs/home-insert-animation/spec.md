## ADDED Requirements

### Requirement: Insert animation for Home feed
The system SHALL animate newly appended Home feed items using the `qh-insert` animation.

#### Scenario: New items animate when appended
- **WHEN** the user clicks "Load More" on the Home feed and new items are appended to the list
- **THEN** at least one visible element corresponding to a newly appended item SHALL have an animation applied where:
  - animation-name: `qh-insert`
  - duration: 220ms
  - timing-function: ease-out
  - effect: fade from opacity 0 to 1 and translateY from 8px to 0

### Requirement: Elm-first application
The system SHALL apply the animation using Elm (inline styles or Elm attributes) on the visible element representing the item, not by overriding elm-ui generated classes.

#### Scenario: Animation applied inline
- **WHEN** an item is marked as inserted by the Elm model
- **THEN** the rendered DOM element for the visible item SHALL include an inline `style` attribute that sets `animation: qh-insert 220ms ease-out both` or equivalent.

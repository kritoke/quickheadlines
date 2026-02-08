## ADDED Requirements

### Requirement: Port elm-ui styling and Theme.semantic
The system SHALL port existing `elm-ui` styling and the `Theme.semantic` tokens so the new `elm-pages` frontend visually matches the previous UI within acceptable visual tolerances.

#### Scenario: Theme tokens available to new code
- **WHEN** a developer imports `Theme` from the new `ui/src/Theme.elm` and uses `Theme.semantic` tokens
- **THEN** components render with consistent spacing, color, and typography compared to the previous `elm-land` implementation

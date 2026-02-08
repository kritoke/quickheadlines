## ADDED Requirements

### Requirement: Implement BackendTask to fetch clusters
The system SHALL implement an `elm-pages` `BackendTask` that fetches news clusters from the existing backend endpoint `GET /api/clusters`. The task SHALL handle pagination, errors, and return typed DTOs compatible with the Elm model.

#### Scenario: Successful BackendTask fetch
- **WHEN** the `BackendTask` executes during pre-render or client navigation
- **THEN** it fetches `GET /api/clusters`, parses the JSON into Elm types, and the page renders the cluster list

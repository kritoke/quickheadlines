## ADDED Requirements

### Requirement: Initialize elm-pages v3
The system SHALL initialize an `elm-pages` v3 project within the `ui/` directory that builds a production Elm bundle compatible with the existing QuickHeadlines serving setup.

#### Scenario: Project initialization succeeds
- **WHEN** a developer runs the provided `make elm-pages-init` or equivalent `nix develop . --command` wrapper
- **THEN** the `ui/` directory contains a minimal `elm.json`, an `elm-pages` entrypoint, and a successful `elm-pages build` producing `public/elm.js` without runtime errors

## ADDED Requirements

### Requirement: Decommission elm-land files
The system SHALL remove or archive the old `elm-land` source files and build artifacts in a way that preserves history but prevents accidental use in CI or local development.

#### Scenario: Old files archived
- **WHEN** migration is complete and `make elm-build` targets reference `elm-pages` instead of `elm-land`
- **THEN** the repository no longer builds `elm-land` artifacts and a migration note exists explaining the archive location and rollback steps

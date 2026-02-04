## ADDED Requirements

### Requirement: FreeBSD dev mode skips elm-land-build when elm.js exists
The build system SHALL skip elm-land-build during development mode on FreeBSD when public/elm.js already exists.

#### Scenario: FreeBSD dev build with existing elm.js
- **WHEN** running `make run` on FreeBSD with existing public/elm.js
- **THEN** system skips elm-land-build and does not install npm packages
- **THEN** system starts server successfully using pre-compiled elm.js

#### Scenario: FreeBSD dev build without elm.js
- **WHEN** running `make run` on FreeBSD without public/elm.js
- **THEN** system reports error that elm.js is required for FreeBSD development</content>
<parameter name="filePath">openspec/changes/fix-freebsd-dev-tailwind/specs/freebsd-dev-build/spec.md
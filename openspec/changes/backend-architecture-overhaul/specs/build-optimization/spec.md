## ADDED Requirements

### Requirement: Separate Frontend/Backend Builds
The system SHALL support separate build processes for frontend and backend.

#### Scenario: Build only backend
- **WHEN** only backend changes are made
- **THEN** backend can be built without rebuilding frontend

#### Scenario: Build only frontend
- **WHEN** only frontend changes are made
- **THEN** frontend can be built independently

### Requirement: Hot Reload in Development
The system SHALL support hot reloading for development.

#### Scenario: Frontend changes auto-reload
- **WHEN** frontend source files are modified
- **THEN** browser reflects changes without full rebuild

### Requirement: Asset Fingerprinting
The system SHALL use asset fingerprinting for cache busting.

#### Scenario: New asset version
- **WHEN** asset content changes
- **THEN** filename includes hash for cache busting

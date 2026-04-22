## MODIFIED Requirements

### Requirement: Bits-UI components remain for maintainability
The system SHALL retain Bits-UI components to avoid maintenance overhead and custom code complexity.

#### Scenario: Bits-UI maintained for component consistency
- **WHEN** UI components are rendered
- **THEN** Bits-UI components are used as intended
- **AND** maintenance burden is reduced compared to custom implementations

### Requirement: Bits-UI optimized through code splitting
The system SHALL optimize Bits-UI bundle size through Vite manualChunks configuration rather than replacement.

#### Scenario: Bits-UI in separate vendor chunk
- **WHEN** application builds
- **THEN** Bits-UI components are placed in a separate vendor-bits-ui chunk
- **AND** long-term caching is improved without losing maintainability benefits
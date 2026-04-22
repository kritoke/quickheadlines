## ADDED Requirements

### Requirement: Design tokens file exists and exports spacing constants
The system SHALL provide a centralized design tokens file at `/frontend/src/lib/design/tokens.ts` that exports spacing constants.

#### Scenario: File exports spacing constants
- **WHEN** the design tokens file is imported
- **THEN** it SHALL export `spacing.compact` (8px), `spacing.default` (12px), and `spacing.spacious` (16px)

### Requirement: Design tokens file exports typography constants
The system SHALL export typography constants including font size and line height.

#### Scenario: File exports typography constants
- **WHEN** the design tokens file is imported
- **THEN** it SHALL export typography.scale with headline, body, auxiliary, and action levels

### Requirement: Design tokens work with custom themes
The system SHALL ensure design tokens integrate with the existing theme system via CSS variables.

#### Scenario: Custom theme uses design tokens
- **WHEN** a custom theme (e.g., matrix, retro) is applied
- **THEN** spacing and typography SHALL render correctly using theme CSS variables

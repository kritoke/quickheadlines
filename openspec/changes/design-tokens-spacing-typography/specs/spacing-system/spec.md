## ADDED Requirements

### Requirement: Spacing uses 4px baseline grid
The system SHALL use spacing values that are multiples of 4px.

#### Scenario: Spacing values are 4px multiples
- **WHEN** spacing tokens are defined
- **THEN** all values SHALL be divisible by 4

### Requirement: Compact spacing for dense UI elements
The system SHALL use 8px (p-2) for compact spacing in dense areas such as list items and button internals.

#### Scenario: Compact spacing applied
- **WHEN** compact spacing is specified
- **THEN** it SHALL render as 8px padding

### Requirement: Default spacing for standard components
The system SHALL use 12px (p-3) for default component padding.

#### Scenario: Default spacing applied
- **WHEN** default spacing is specified
- **THEN** it SHALL render as 12px padding

### Requirement: Spacious spacing for main content areas
The system SHALL use 16px (p-4) for main content areas and section separation.

#### Scenario: Spacious spacing applied
- **WHEN** spacious spacing is specified
- **THEN** it SHALL render as 16px padding

### Requirement: Components use consistent spacing
The system SHALL ensure all UI components use the defined spacing system consistently.

#### Scenario: Components apply consistent spacing
- **WHEN** FeedBox, Card, AppHeader, or TimelineView are rendered
- **THEN** they SHALL use only the defined spacing values (compact, default, or spacious)

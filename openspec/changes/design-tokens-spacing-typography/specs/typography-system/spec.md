## ADDED Requirements

### Requirement: Typography scale has 4 distinct levels
The system SHALL define a typography scale with exactly 4 levels: headline, body, auxiliary, and action.

#### Scenario: Typography scale defined
- **WHEN** typography tokens are loaded
- **THEN** there SHALL be 4 distinct font-size values in ascending order

### Requirement: Headline typography for main titles
The system SHALL use text-xl font-bold for headline content such as page titles and section headers.

#### Scenario: Headline renders correctly
- **WHEN** a headline element is rendered
- **THEN** it SHALL use 20px font size with bold weight

### Requirement: Body typography for primary content
The system SHALL use text-base for primary content such as feed items and article text.

#### Scenario: Body text renders correctly
- **WHEN** body text is rendered
- **THEN** it SHALL use 16px font size with normal weight

### Requirement: Auxiliary typography for secondary content
The system SHALL use text-sm for secondary content such as timestamps and metadata.

#### Scenario: Auxiliary text renders correctly
- **WHEN** auxiliary text is rendered
- **THEN** it SHALL use 14px font size with normal weight

### Requirement: Action typography for buttons and controls
The system SHALL use text-xs for interactive elements such as buttons and links.

#### Scenario: Action text renders correctly
- **WHEN** action text is rendered
- **THEN** it SHALL use 12px font size with medium weight

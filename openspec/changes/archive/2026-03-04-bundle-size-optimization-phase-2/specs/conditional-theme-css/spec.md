## ADDED Requirements

### Requirement: Theme CSS loads conditionally
The system SHALL load theme-specific CSS only when needed, reducing critical CSS size.

#### Scenario: Base styles loaded initially
- **WHEN** application loads
- **THEN** only base styles and active theme's minimal CSS are loaded
- **AND** critical CSS size is reduced by 33%

### Requirement: Theme switching remains functional
The system SHALL maintain all theme switching functionality while loading CSS conditionally.

#### Scenario: Theme switching with conditional CSS
- **WHEN** user switches themes
- **THEN** the new theme's CSS is loaded asynchronously
- **AND** visual transition is smooth without breaking layout
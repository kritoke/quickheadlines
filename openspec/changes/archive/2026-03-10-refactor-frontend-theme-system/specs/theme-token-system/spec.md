## ADDED Requirements

### Requirement: Unified Theme Token Architecture
The system SHALL replace CSS override-based theming with a unified token-driven system using CSS custom properties, eliminating all `!important` declarations and hardcoded theme-specific CSS blocks while preserving identical visual appearance across all 13 themes.

#### Scenario: Eliminate CSS overrides
- **WHEN** app.css is examined after implementation
- **THEN** it contains zero lines with `!important` declarations for theme colors
- **AND** no hardcoded theme blocks like `html[data-theme="hotdog"]` or `html[data-theme="sunset"]`

#### Scenario: Preserve Hot Dog Stand appearance
- **WHEN** Hot Dog Stand theme is active
- **THEN** all UI elements display with bg: '#008080', text: '#ffff00', border: '#c0c0c0'
- **AND** visual appearance is pixel-perfect identical to current implementation

### Requirement: Programmatically Generated CSS Variables
The system SHALL generate all CSS custom properties programmatically from theme tokens, ensuring single source of truth between JavaScript tokens and CSS variables without manual maintenance.

#### Scenario: Theme token to CSS variable mapping
- **WHEN** theme tokens define { bg: '#1a1a2e', accent: '#00d4ff' }
- **THEN** document.documentElement.style contains --theme-bg: #1a1a2e, --theme-accent: #00d4ff

#### Scenario: Dynamic theme switching
- **WHEN** user switches from Light to Matrix theme
- **THEN** all CSS variables update immediately to reflect new theme colors
- **AND** UI re-renders with new colors without page reload

### Requirement: Maintain Mouse Cursor Trail Functionality
The system SHALL preserve existing mouse cursor trail effects with identical behavior, sourcing colors from theme tokens while maintaining iOS detection and touch event handling.

#### Scenario: Cursor trail with theme colors
- **WHEN** cursor trail is enabled in Retro 80s theme
- **THEN** primary cursor displays in '#00d4ff' and trail displays with 'rgba(0, 212, 255, 0.4)'
- **AND** trail animation maintains 50ms delay and spring physics

#### Scenario: iOS cursor trail disable
- **WHEN** app runs on iOS device with cursor trail enabled
- **THEN** cursor trail effects are automatically disabled for performance
- **AND** effect toggle button remains functional but has no visual impact
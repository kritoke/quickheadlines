## ADDED Requirements

### Requirement: Unified Theme Configuration
The application SHALL provide a single theme configuration object containing all theme-related colors.

#### Scenario: Theme configuration structure
- **WHEN** accessing theme configuration
- **THEN** there SHALL be a single `themes` object containing all theme definitions
- **AND** each theme SHALL contain all color properties (bg, text, border, accent, shadow, cursor, etc.)

#### Scenario: Adding new theme
- **WHEN** a developer adds a new theme to the configuration
- **THEN** they SHALL only need to update ONE data structure
- **AND** all theme-related colors SHALL be automatically available

### Requirement: Type-Safe Theme Access
The application SHALL provide type-safe functions for accessing theme colors.

#### Scenario: Theme function type safety
- **WHEN** calling `getThemeColors(theme)` with an invalid theme
- **THEN** TypeScript SHALL raise a compile-time type error

#### Scenario: Theme function returns complete colors
- **WHEN** calling any theme color function (getThemeAccentColors, getCursorColors, etc.)
- **THEN** all functions SHALL return colors from the same unified configuration

### Requirement: Theme Application
The application SHALL apply theme colors consistently across all components.

#### Scenario: Theme applies to document
- **WHEN** `applyTheme(theme)` is called
- **THEN** the document SHALL have appropriate CSS classes applied
- **AND** custom theme colors SHALL be set as CSS variables

#### Scenario: Theme persists across page loads
- **WHEN** a user selects a theme
- **THEN** the theme SHALL be saved to localStorage
- **AND** the theme SHALL be restored on page reload

### Requirement: Theme Detection
The application SHALL respect system theme preferences.

#### Scenario: Initial theme from system preference
- **WHEN** no theme is saved in localStorage
- **THEN** the application SHALL detect system preference using prefers-color-scheme
- **AND** apply 'dark' if system is in dark mode, 'light' otherwise

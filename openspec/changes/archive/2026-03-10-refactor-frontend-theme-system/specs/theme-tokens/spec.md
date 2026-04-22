## MODIFIED Requirements

### Requirement: Unified Theme Token API
The system SHALL provide a single `getThemeTokens(theme)` function that returns all theme-related values (colors, preview, cursor, scroll button, dot indicator) to replace multiple separate getter functions.

#### Scenario: Get all tokens for a theme
- **WHEN** caller invokes `getThemeTokens('dark')`
- **THEN** function returns object containing: `{ colors: ThemeColors, preview: string, cursor: { primary: string, trail: string }, scrollButton: { bg: string, text: string, hover: string }, dotIndicator: string }`

#### Scenario: Get tokens for Hot Dog Stand theme
- **WHEN** caller invokes `getThemeTokens('hotdog')`
- **THEN** function returns valid theme tokens with bg: '#008080', text: '#fff59d'

### Requirement: CSS Variables as Theme Source
The system SHALL set CSS custom properties (`--theme-bg`, `--theme-accent`, etc.) on the document root when applying a theme, allowing CSS to reference theme colors without JavaScript function calls.

#### Scenario: Apply theme sets CSS variables
- **WHEN** `applyTheme('retro80s')` is called
- **THEN** document.documentElement.style contains `--theme-bg: #1a1a2e`, `--theme-accent: #00d4ff`, `--theme-shadow: rgba(255, 46, 99, 0.3)`

#### Scenario: CSS variables available in stylesheets
- **WHEN** component uses `var(--theme-accent)` in styles
- **THEN** the value resolves to the current theme's accent color

### Requirement: Minimal CSS Theme Blocks
The system SHALL keep theme-specific styling in JavaScript/TypeScript, with CSS containing only base tokens, scrollbar styles, animations, and utility classes—no hardcoded theme color blocks.

#### Scenario: app.css contains only base styles
- **WHEN** app.css is examined
- **THEN** it does NOT contain hardcoded theme blocks like `html[data-theme="matrix"]`, `html[data-theme="retro80s"]`, or theme-specific color overrides
- **AND** duplicate theme definitions removed (app.css reduced from 441 to ~200 lines)

## ADDED Requirements

### Requirement: Component Prop-Based Theming
The system SHALL enable components to receive theme tokens as props for type-safe, explicit theming instead of relying on global CSS inheritance or data attributes.

#### Scenario: Component receives theme prop
- **WHEN** FeedBox component is instantiated
- **THEN** it can optionally receive themeColors prop containing current theme tokens
- **AND** falls back to global theme state if prop not provided for backward compatibility

### Requirement: Comprehensive Theme Token Coverage
The system SHALL ensure all 13 themes have complete token definitions covering every visual aspect including focus rings, scrollbar colors, and interactive states.

#### Scenario: Hot Dog Stand complete tokens
- **WHEN** Hot Dog Stand theme tokens are examined
- **THEN** they include focus ring colors (#ff0000), scrollbar colors, and all interactive states
- **AND** no visual elements fall back to default colors

#### Scenario: Theme extensibility
- **WHEN** new theme is added to theme configuration
- **THEN** it automatically works across all components without additional CSS overrides
- **AND** follows same token structure as existing themes
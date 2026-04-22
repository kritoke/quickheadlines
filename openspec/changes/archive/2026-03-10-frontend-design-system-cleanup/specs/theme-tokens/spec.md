## ADDED Requirements

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

### Requirement: Component Styling via Card
Feed display components SHALL use the `<Card>` UI component with appropriate variant props instead of inline Tailwind class bindings.

#### Scenario: FeedBox uses Card component
- **WHEN** FeedBox renders with default variant
- **THEN** output includes Card's base styles: rounded-lg border, shadow-sm, background color from theme

### Requirement: Minimal CSS Theme Blocks
The system SHALL keep theme-specific styling in JavaScript/TypeScript, with CSS containing only base tokens, scrollbar styles, animations, and utility classes—no hardcoded theme color blocks.

#### Scenario: app.css contains only base styles
- **WHEN** app.css is examined
- **THEN** it does NOT contain hardcoded theme blocks like `html[data-theme="matrix"]`, `html[data-theme="retro80s"]`, or theme-specific color overrides

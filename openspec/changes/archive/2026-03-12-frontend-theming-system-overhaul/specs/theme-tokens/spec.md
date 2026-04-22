# theme-tokens Specification (Delta)

## MODIFIED Requirements

### Requirement: Minimal CSS Theme Blocks
The system SHALL keep theme-specific styling in JavaScript/TypeScript, with CSS containing only base tokens, scrollbar styles, animations, and utility classes—no hardcoded theme color blocks and NO `!important` overrides.

#### Scenario: app.css contains only base styles
- **WHEN** app.css is examined
- **THEN** it does NOT contain:
  - Hardcoded theme blocks like `html[data-theme="matrix"]`, `html[data-theme="retro80s"]`
  - Theme-specific color overrides for Tailwind utilities
  - Any selector containing `html.custom-theme`
- **AND** duplicate theme definitions removed (app.css reduced from ~276 to ~120 lines)

#### Scenario: No important overrides in CSS
- **WHEN** app.css is examined for `!important` declarations related to theming
- **THEN** no theme-related `!important` overrides exist
- **AND** all theme styling uses CSS custom properties with proper cascade

#### Scenario: Semantic tokens used instead of overrides
- **WHEN** component needs themed styling
- **THEN** it uses semantic utility classes (e.g., `.theme-bg-primary`) that reference CSS variables
- **AND** NOT `!important` overrides on Tailwind utilities

### Requirement: CSS Variables as Theme Source
The system SHALL set CSS custom properties (`--theme-bg`, `--theme-accent`, etc.) on the document root when applying a theme, allowing CSS to reference theme colors without JavaScript function calls.

#### Scenario: Apply theme sets CSS variables
- **WHEN** `applyTheme('retro')` is called
- **THEN** document.documentElement.style contains `--theme-bg: #1a1a2e`, `--theme-accent: #00d4ff`, `--theme-shadow: rgba(255, 113, 206, 0.3)`

#### Scenario: CSS variables available in stylesheets
- **WHEN** component uses `var(--theme-accent)` in styles
- **THEN** the value resolves to the current theme's accent color

#### Scenario: Semantic tokens also set alongside theme-specific
- **WHEN** `applyTheme('ocean')` is called
- **THEN** document.documentElement.style contains both:
  - Theme-specific: `--theme-bg: #2e3440`, `--theme-accent: #88c0d0`
  - Semantic: `--color-bg-primary: #2e3440`, `--color-accent: #88c0d0`

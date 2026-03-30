# theme-tokens Specification

## Purpose
Centralizes theme token management in the frontend, providing a unified API for accessing theme colors, cursors, and other visual properties while maintaining CSS variables for performant styling.

## Requirements

### Requirement: Unified Theme Token API
The system SHALL provide a single `getThemeTokens(theme)` function that returns all theme-related values (colors, preview, cursor, scroll button, dot indicator) to replace multiple separate getter functions.

#### Scenario: Get all tokens for a theme
- **WHEN** caller invokes `getThemeTokens('dark')`
- **THEN** function returns object containing: `{ colors: ThemeColors, preview: string, cursor: { primary: string, trail: string }, scrollButton: { bg: string, text: string, hover: string }, dotIndicator: string }`

#### Scenario: Get tokens for Hot Dog Stand theme
- **WHEN** caller invokes `getThemeTokens('hotdog')`
- **THEN** function returns valid theme tokens with bg: '#008080', text: '#fff59d'

### Requirement: CSS Variables as Theme Source
The system SHALL set CSS custom properties (`--theme-bg`, `--theme-accent`, etc.) on the document root when applying a theme, allowing CSS to reference theme colors without JavaScript function calls. This now includes `--theme-bg-secondary` and `--theme-text-secondary` which were previously omitted after hydration.

#### Scenario: Apply theme sets all CSS variables
- **WHEN** `applyTheme('retro')` is called
- **THEN** document.documentElement.style contains `--theme-bg: #1a1a2e`, `--theme-accent: #00d4ff`, `--theme-shadow: rgba(255, 113, 206, 0.3)`, `--theme-bg-secondary: #0d0d1a`, `--theme-text-secondary: #cbd5e1`

#### Scenario: CSS variables available in stylesheets
- **WHEN** component uses `var(--theme-accent)` in styles
- **THEN** the value resolves to the current theme's accent color

#### Scenario: Semantic tokens also set alongside theme-specific
- **WHEN** `applyTheme('ocean')` is called
- **THEN** document.documentElement.style contains both:
  - Theme-specific: `--theme-bg: #2e3440`, `--theme-accent: #88c0d0`, `--theme-bg-secondary: #242933`, `--theme-text-secondary: #81a1c1`
  - Semantic: `--color-bg-primary: #2e3440`, `--color-accent: #88c0d0`, `--color-bg-secondary: #242933`, `--color-text-secondary: #81a1c1`

#### Scenario: Inter font applied via Tailwind
- **WHEN** Tailwind `font-sans` utility is used on any element
- **THEN** the rendered font-family includes `Inter` as the first choice
- **AND** `Inter` is loaded via the existing Google Fonts link in `app.html`

### Requirement: Minimal CSS Theme Blocks
The system SHALL keep theme-specific styling in JavaScript/TypeScript, with CSS containing only base tokens, scrollbar styles, animations, and utility classes—no hardcoded theme color blocks and NO `!important` overrides.

#### Scenario: app.css contains only base styles
- **WHEN** app.css is examined
- **THEN** it does NOT contain:
  - Hardcoded theme blocks like `html[data-theme="matrix"]`, `html[data-theme="retro"]`
  - Theme-specific color overrides for Tailwind utilities
  - Any selector containing `html.custom-theme`
- **AND** duplicate theme definitions removed (app.css reduced from ~276 to ~120 lines)

#### Scenario: No important overrides in CSS
- **WHEN** app.css is examined for `!important` declarations related to theming
- **THEN** no theme-related `!important` overrides exist (except for targeted custom theme overrides using :where selector)
- **AND** all theme styling uses CSS custom properties with proper cascade

#### Scenario: Semantic tokens used instead of overrides
- **WHEN** component needs themed styling
- **THEN** it uses semantic utility classes (e.g., `.theme-bg-primary`) that reference CSS variables
- **AND** NOT `!important` overrides on Tailwind utilities

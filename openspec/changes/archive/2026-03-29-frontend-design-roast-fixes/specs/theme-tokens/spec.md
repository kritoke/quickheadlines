## MODIFIED Requirements

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

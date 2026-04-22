# semantic-theme-tokens Specification

## Purpose
Provides semantic CSS custom properties that map to theme values, enabling components to use meaningful class names instead of relying on Tailwind utility overrides with `!important`.

## Requirements

### Requirement: Semantic Token CSS Variables
The system SHALL set semantic CSS custom properties on the document root when applying a theme, providing a meaningful layer between theme values and component styles.

#### Scenario: Apply theme sets semantic variables
- **WHEN** `applyTheme('retro')` is called
- **THEN** document.documentElement.style contains:
  - `--color-bg-primary: #1a1a2e`
  - `--color-bg-secondary: #0d0d1a`
  - `--color-text-primary: #f1f5f9`
  - `--color-text-secondary: #cbd5e1`
  - `--color-border: #ff71ce`
  - `--color-accent: #00d4ff`

#### Scenario: Semantic variables available in CSS
- **WHEN** component uses `var(--color-bg-primary)` in styles
- **THEN** the value resolves to the current theme's primary background color

### Requirement: Fallback Values
Semantic CSS variables SHALL fall back to theme-specific variables for backward compatibility during migration.

#### Scenario: Fallback when semantic token not set
- **WHEN** component uses `.theme-bg-primary` class without semantic tokens configured
- **THEN** it falls back to `var(--theme-bg)` value

#### Scenario: Fallback chain works correctly
- **WHEN** CSS rule is `.theme-bg-primary { background-color: var(--color-bg-primary, var(--theme-bg)); }`
- **THEN** if neither variable is set, background renders transparent (browser default)

### Requirement: Semantic Token Utility Classes
The system SHALL provide CSS utility classes that use semantic variables, allowing components to opt into semantic styling without code changes.

#### Scenario: Utility class uses semantic variable
- **WHEN** component has `class="theme-bg-primary theme-text-primary"`
- **THEN** background uses `--color-bg-primary` and text uses `--color-text-primary`

#### Scenario: Dark mode compatibility
- **WHEN** Tailwind dark mode is active AND component uses semantic class
- **THEN** semantic variable reflects dark theme values (no conflict with `dark:` modifier)

### Requirement: Token Coverage
The system SHALL provide semantic tokens for core visual properties: background, text, border, and accent colors.

#### Scenario: All core tokens available
- **WHEN** theme is applied
- **THEN** the following semantic tokens are set:
  - `--color-bg-primary` (main background)
  - `--color-bg-secondary` (cards, headers)
  - `--color-text-primary` (headings, body text)
  - `--color-text-secondary` (metadata, timestamps)
  - `--color-border` (dividers, outlines)
  - `--color-accent` (links, highlights)

### Requirement: No Important Overrides
The semantic token system SHALL NOT use `!important` to override Tailwind or any other utility classes.

#### Scenario: No important in semantic CSS
- **WHEN** app.css is examined for semantic token classes
- **THEN** no `!important` declarations are found in the semantic token CSS
- **AND** no `html.custom-theme` selector blocks exist

#### Scenario: Components choose semantic over Tailwind
- **WHEN** component migrates to semantic classes
- **THEN** it no longer needs `html.custom-theme` override blocks
- **AND** styling works through normal CSS cascade

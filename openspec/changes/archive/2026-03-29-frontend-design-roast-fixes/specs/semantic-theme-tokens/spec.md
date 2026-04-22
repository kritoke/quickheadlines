## MODIFIED Requirements

### Requirement: Hover states use semantic classes
Components SHALL use semantic theme classes for hover states to maintain theme consistency. This extends to all hardcoded color references in interactive elements.

#### Scenario: Header title text uses semantic theme class
- **WHEN** `AppHeader.svelte` renders the site title
- **THEN** title text uses `theme-text-primary` class (or equivalent semantic token)
- **AND** does NOT use hardcoded `text-slate-900` or `dark:text-white`
- **AND** title is visible and readable in all 10 themes

#### Scenario: Loading spinners use theme accent color
- **WHEN** loading spinner renders on feeds page or timeline page
- **THEN** spinner border uses `theme-accent` or `var(--color-accent)` class/variable
- **AND** does NOT use hardcoded `border-blue-500`

#### Scenario: Hover state works across all themes
- **WHEN** any of the 10 themes is applied
- **AND** timeline item is hovered
- **THEN** hover background provides sufficient contrast for readability
- **AND** hover does not reduce text/icon opacity

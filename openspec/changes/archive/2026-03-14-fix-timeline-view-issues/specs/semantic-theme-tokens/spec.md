## MODIFIED Requirements

### Requirement: No Important Overrides
The semantic token system SHALL NOT use `!important` to override Tailwind or any other utility classes.

#### Scenario: No important in semantic CSS
- **WHEN** app.css is examined for semantic token classes
- **THEN** no `!important` declarations are found in the semantic token CSS
- **AND** no `html.custom-theme` selector blocks exist with !important overrides

#### Scenario: Components choose semantic over Tailwind
- **WHEN** component migrates to semantic classes
- **THEN** it no longer needs `html.custom-theme` override blocks
- **AND** styling works through normal CSS cascade

#### Scenario: Custom theme override using specificity
- **WHEN** custom theme is applied
- **THEN** html.custom-theme styles use more specific selectors (e.g., `.theme-bg-primary { background-color: var(--theme-bg); }`) instead of `!important`
- **AND** these styles cascade correctly without overriding utility class intentions

### Requirement: Hover states use semantic classes
Components SHALL use semantic theme classes for hover states to maintain theme consistency.

#### Scenario: Timeline item hover uses semantic class
- **WHEN** timeline item is hovered
- **THEN** background color changes to theme-aware secondary background
- **AND** this is achieved through semantic classes (e.g., `hover:theme-bg-secondary`)
- **AND** NOT through opacity changes that affect text and icons

#### Scenario: Hover state works across all themes
- **WHEN** any of the 10 themes is applied
- **AND** timeline item is hovered
- **THEN** hover background provides sufficient contrast for readability
- **AND** hover does not reduce text/icon opacity

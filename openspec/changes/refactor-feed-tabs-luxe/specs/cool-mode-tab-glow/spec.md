## Requirement: Tab Glow Effect

### Scenario: Glow appears in cool mode
- **WHEN** themeState.coolMode is true
- **AND** a tab is active
- **THEN** the active pill SHALL have box-shadow of `0 0 15px -3px rgba(150, 173, 141, 0.4)`
- **AND** the border SHALL use accent color at 30% opacity

### Scenario: No glow when cool mode disabled
- **WHEN** themeState.coolMode is false
- **THEN** the active pill SHALL NOT have the glow effect

### Requirement: Accent Color
The glow effect SHALL use the Wasabi Green accent color (#96ad8d).

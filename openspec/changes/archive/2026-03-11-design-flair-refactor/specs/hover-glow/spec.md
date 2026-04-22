## ADDED Requirements

### Requirement: Hover glow appears on feed cards
When the user enables effects in the app header, hovering over a feed card SHALL display a theme-colored glow shadow.

#### Scenario: Hover glow displays on desktop
- **WHEN** effects are enabled AND user hovers over a feed card on a device with hover capability
- **THEN** a shadow using the current theme's accent color appears around the card

#### Scenario: No hover glow when effects disabled
- **WHEN** effects are disabled
- **THEN** hovering over a feed card shows no additional glow

#### Scenario: Hover glow uses theme-specific colors
- **WHEN** user selects any of the 13 themes (light, dark, retro80s, matrix, ocean, sunset, hotdog, dracula, nord, cyberpunk, forest, coffee, vaporwave)
- **THEN** the hover glow uses that theme's accent color from the theme configuration

### Requirement: Hover glow works on all themes
The hover glow effect SHALL be available regardless of which theme is selected.

#### Scenario: Glow visible on dark theme
- **WHEN** dark theme is selected AND effects enabled AND user hovers over feed card
- **THEN** hover glow is visible using dark theme's accent color

#### Scenario: Glow visible on Hot Dog Stand theme
- **WHEN** Hot Dog Stand theme is selected AND effects enabled AND user hovers over feed card
- **THEN** hover glow is visible using Hot Dog Stand theme's accent color (red)

#### Scenario: Glow visible on Vaporwave theme
- **WHEN** Vaporwave theme is selected AND effects enabled AND user hovers over feed card
- **THEN** hover glow is visible using Vaporwave theme's accent color (pink)

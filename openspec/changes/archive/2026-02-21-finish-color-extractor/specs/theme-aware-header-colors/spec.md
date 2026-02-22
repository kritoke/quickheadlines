## ADDED Requirements

### Requirement: Theme-aware header colors
The system SHALL provide theme-aware header colors for feeds and items. For each feed the server SHALL produce a JSON structure storing the header background color and two text colors, one for light theme and one for dark theme. The JSON SHALL have the keys: `bg`, `text.light`, `text.dark`, and `source`.

#### Scenario: Server returns theme-aware colors
- **WHEN** a client requests feed or timeline data for a feed with computed header colors
- **THEN** the API response SHALL include `header_theme_colors` with `bg` and both `text` colors

### Requirement: Contrast validation
The system SHALL validate that each `text` color has a contrast ratio of at least 4.5:1 against the `bg` color according to WCAG 2.1 sRGB luminance formulas. If the chosen color does not meet the threshold the system SHALL adjust the color to meet it.

#### Scenario: Auto-adjust failing color
- **WHEN** extraction produces a `bg` color and default `text` value (`#000000` or `#FFFFFF`) fails contrast validation
- **THEN** the server SHALL compute an adjusted color that meets 4.5:1 and store it in `header_theme_colors`

### Requirement: Backwards compatibility
If `header_theme_colors` is not present for a feed, the API SHALL fall back to the legacy `header_text_color` field if present. Clients SHALL handle both formats.

#### Scenario: Legacy client
- **WHEN** a client requests timeline data for a feed without `header_theme_colors` but with legacy `header_text_color`
- **THEN** the API SHALL include `header_text_color` and not `header_theme_colors`

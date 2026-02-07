## ADDED Requirements

### Requirement: Validate header theme JSON on write
The system SHALL validate `header_theme_colors` JSON before persisting a feed row. Validation includes ensuring any declared text color roles (`light.text`, `dark.text`, `light.role`, `dark.role` or equivalent) meet WCAG contrast ratio of at least 4.5:1 against their associated background colors.

#### Scenario: Valid theme saved unchanged
- **WHEN** a feed row is inserted or updated with `header_theme_colors` where both light and dark text roles meet contrast >= 4.5:1
- **THEN** the system SHALL persist the provided JSON unchanged and SHALL NOT write a corrective payload.

#### Scenario: Invalid theme triggers auto-correction
- **WHEN** a feed row is inserted or updated with `header_theme_colors` where one or more text roles fail the contrast requirement
- **THEN** the system SHALL compute corrected text role colors (using deterministic selection) and persist corrected JSON with `source` set to `auto-corrected`.

### Requirement: Upgrade safe `auto` themes to `auto-corrected`
The system SHALL upgrade `header_theme_colors.source` from `auto` to `auto-corrected` without changing other values when both light and dark roles already meet the contrast requirement.

#### Scenario: Upgrade without modification
- **WHEN** a feed row has `header_theme_colors.source == "auto"` and both roles meet contrast
- **THEN** the system SHALL update `source` to `auto-corrected` and otherwise leave JSON untouched.

### Requirement: No overwrite of explicit user colors
The system SHALL NOT overwrite `header_color` or `header_text_color` fields when they appear to be explicit user-provided overrides. Auto-correction applies only to `header_theme_colors` stored as JSON or when legacy fields are absent.

#### Scenario: User override preserved
- **WHEN** a feed row contains non-null `header_text_color` or `header_color`
- **THEN** the system SHALL NOT change these fields during auto-correction operations

## ADDED Requirements

### Requirement: Server SHALL validate header_text_color contrast
The server SHALL validate any `header_text_color` stored in `feeds.header_theme_colors` against its `bg` value using relative luminance and WCAG contrast ratio formula. The server SHALL treat a color as unsafe if the contrast ratio is less than 4.5:1 for normal text.

#### Scenario: Detect unsafe color
- **WHEN** a feed is created or updated with `header_theme_colors` that contains `bg` and `text` candidates
- **THEN** the server computes the contrast ratio for each candidate and marks the feed record as needing correction if none meet 4.5:1

### Requirement: Server SHALL auto-correct unsafe header_text_color
If no existing candidate text colors meet 4.5:1, the server SHALL generate a corrected color by adjusting luminance while preserving hue and saturation (HSL) until the contrast threshold is reached. The server SHALL prefer the minimal luminance change.

#### Scenario: Generate corrected color
- **WHEN** a feed `bg` is provided and candidate text colors all have contrast < 4.5:1
- **THEN** the server generates a new `text` color that meets 4.5:1 and annotates `header_theme_colors.source` with `"auto-corrected"` and returns the updated `header_theme_colors` in API responses

### Requirement: Corrections SHALL be persistent and safe to run multiple times
The backfill script and extraction path SHALL persist corrected `header_theme_colors` and SHALL be idempotent. Running backfill multiple times SHALL not produce duplicate side effects.

#### Scenario: Backfill idempotence
- **WHEN** the backfill script runs on all feeds
- **THEN** feeds that already have `header_theme_colors.source == "auto-corrected"` remain unchanged unless a new condition requires re-computation (e.g., changed `bg`)

### Requirement: API SHALL expose corrected colors
API responses for feeds and timelines SHALL include the corrected `header_theme_colors` without changing existing field names. Consumers SHALL be able to detect `source == "auto-corrected"`.

#### Scenario: API response includes corrected color
- **WHEN** a client requests feed metadata via `/api/feeds` or timeline endpoints
- **THEN** the returned JSON includes `header_theme_colors.bg`, `header_theme_colors.text`, and `header_theme_colors.source` with `"auto-corrected"` when applicable

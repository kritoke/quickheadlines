## ADDED Requirements

### Requirement: Extract dominant color from image file
The system SHALL extract the dominant color from an image file (PNG, JPG, ICO) using Prismatiq's MMCQ algorithm.

#### Scenario: Extract from valid PNG
- **GIVEN** a valid PNG favicon file exists at `/favicons/example.png`
- **WHEN** `ColorExtractor.theme_aware_extract_from_favicon` is called with the path
- **THEN** it returns a Hash containing "bg" and "text" keys with color values

#### Scenario: Extract from ICO file
- **GIVEN** a valid ICO file exists at `/favicons/example.ico`
- **WHEN** `ColorExtractor.theme_aware_extract_from_favicon` is called with the path
- **THEN** it extracts the dominant color from the best icon in the ICO

#### Scenario: Handle missing file
- **GIVEN** a non-existent file path
- **WHEN** `ColorExtractor.theme_aware_extract_from_favicon` is called
- **THEN** it returns nil

### Requirement: Generate WCAG-compliant text colors
The system SHALL generate text colors that meet WCAG AA contrast requirements (4.5:1 ratio).

#### Scenario: Light background
- **GIVEN** a light background color (e.g., #FFFFFF)
- **WHEN** text colors are generated
- **THEN** the dark text color has contrast >= 4.5:1 against the background

#### Scenario: Dark background
- **GIVEN** a dark background color (e.g., #000000)
- **WHEN** text colors are generated
- **THEN** the light text color has contrast >= 4.5:1 against the background

### Requirement: Cache extraction results
The system SHALL cache color extraction results for 7 days to avoid redundant processing.

#### Scenario: Repeated extraction
- **GIVEN** a color was extracted and cached
- **WHEN** the same file is extracted again within 7 days
- **THEN** the cached result is returned without re-processing

### Requirement: Theme JSON correction
The system SHALL correct theme JSON to ensure valid text colors when provided.

#### Scenario: Valid theme JSON
- **GIVEN** a valid theme JSON with both "light" and "dark" text colors
- **WHEN** `ColorExtractor.auto_correct_theme_json` is called
- **THEN** it returns the theme JSON unchanged

#### Scenario: Missing text colors
- **GIVEN** a theme JSON with only background color, no text colors
- **WHEN** `ColorExtractor.auto_correct_theme_json` is called
- **THEN** it generates and adds compliant text colors

#### Scenario: Legacy format
- **GIVEN** legacy theme format with string text color (not object)
- **WHEN** `ColorExtractor.auto_correct_theme_json` is called
- **THEN** it converts to the new format with both light/dark variants

### Requirement: Manual color override support
The system SHALL respect manually configured header colors in feeds.yml.

#### Scenario: Configured header color
- **GIVEN** a feed has a manually configured `header_color` in feeds.yml
- **WHEN** color extraction is attempted
- **THEN** it returns nil to indicate no extraction needed (config takes precedence)

### Requirement: Calculate color contrast
The system SHALL calculate WCAG contrast ratios between colors.

#### Scenario: Black on white
- **WHEN** contrast is calculated between black and white
- **THEN** the result is 21:1

#### Scenario: Insufficient contrast
- **GIVEN** two colors with contrast < 4.5:1
- **WHEN** contrast is calculated
- **THEN** the result reflects the actual ratio (e.g., 2.5:1)

### Requirement: Calculate relative luminance
The system SHALL calculate relative luminance per WCAG formula.

#### Scenario: Pure white
- **WHEN** luminance is calculated for white (255,255,255)
- **THEN** the result is 1.0

#### Scenario: Pure black
- **WHEN** luminance is calculated for black (0,0,0)
- **THEN** the result is 0.0

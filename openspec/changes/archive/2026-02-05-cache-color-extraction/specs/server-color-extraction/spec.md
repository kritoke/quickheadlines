# Spec: server-color-extraction

Capability: server-color-extraction

Purpose
- Extract dominant colors from favicons during feed fetch on the server, eliminating client-side delays and ensuring immediate availability of colors in API responses.

Background
- Proposal: Move color extraction to server-side during feed fetch. Design: Use stumpy_png for PNG processing, YIQ formula for contrast calculation.

## ADDED Requirements

### Requirement: Server extracts colors from favicons
When a feed is fetched and a favicon is successfully downloaded to local storage, the system SHALL extract the dominant background color and contrasting text color from the favicon image.

#### Scenario: Favicon extracted during feed fetch
- **WHEN** `fetch_feed()` successfully downloads a favicon to `/favicons/<hash>.png`
- **THEN** the system SHALL parse the PNG file using stumpy_png
- **AND** SHALL calculate the dominant color using pixel sampling
- **AND** SHALL compute text color using YIQ luminance formula

#### Scenario: Extraction uses YIQ contrast calculation
- **WHEN** extracting text color from a background color with RGB values
- **THEN** the system SHALL compute: `yiq = (r * 299 + g * 587 + b * 114) / 1000`
- **AND** SHALL use dark text (`#1f2937`) when yiq >= 128
- **AND** SHALL use light text (`#ffffff`) when yiq < 128

### Requirement: User overrides take priority
When a feed has a manual `header_color` defined in `feeds.yml`, the system SHALL NOT extract or overwrite colors for that feed.

#### Scenario: Manual color override respected
- **WHEN** a feed configuration includes `header_color` in feeds.yml
- **THEN** the system SHALL use the configured color values
- **AND** SHALL NOT perform server-side color extraction
- **AND** SHALL NOT overwrite the database values with extracted colors

#### Scenario: No override uses extracted colors
- **WHEN** a feed has no `header_color` in feeds.yml
- **AND** the database has no existing `header_color`
- **THEN** the system SHALL save extracted colors to the database
- **AND** the colors SHALL be available in subsequent API responses

### Requirement: Extracted colors saved to database
Extracted colors SHALL be persisted in the `feeds` table columns `header_color` and `header_text_color`.

#### Scenario: Colors saved during feed persistence
- **WHEN** `update_or_create_feed()` is called with extracted colors
- **THEN** the system SHALL save `header_color` and `header_text_color` to the feeds table
- **AND** the colors SHALL be included in the FeedData returned to callers

#### Scenario: API includes colors in response
- **WHEN** `/api/timeline` endpoint returns timeline items
- **THEN** each item SHALL include `header_color` and `header_text_color` from the feed's database record
- **AND** the colors SHALL be available immediately on first page load

### Requirement: Extraction cached by favicon
The system SHALL cache extracted colors by favicon file path to avoid re-extracting the same image.

#### Scenario: Same favicon reuses extraction result
- **WHEN** a feed is refreshed with the same favicon URL
- **THEN** the system SHALL reuse previously extracted colors
- **AND** SHALL NOT re-process the favicon image

#### Scenario: Different favicon triggers new extraction
- **WHEN** a feed's favicon URL changes
- **THEN** the system SHALL extract colors from the new favicon
- **AND** SHALL update the cached colors in the database

### Requirement: Graceful fallback on extraction failure
If color extraction fails (invalid image, unsupported format), the system SHALL continue without extracted colors.

#### Scenario: Invalid PNG handled gracefully
- **WHEN** stumpy_png cannot parse the favicon file
- **THEN** the system SHALL log a debug message
- **AND** SHALL continue feed processing without colors
- **AND** SHALL NOT crash or abort the feed fetch

#### Scenario: Non-PNG favicon skipped
- **WHEN** the favicon is not a PNG image
- **THEN** the system SHALL skip color extraction
- **AND** SHALL NOT attempt to parse the file

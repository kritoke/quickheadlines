## ADDED Requirements

### Requirement: Backfill extracts theme from favicons and site homepages
The backfill utility SHALL attempt to extract theme colors for each feed by using, in order of preference: (1) saved local favicon blob, (2) site homepage parsing for `<link rel="icon">`, `<link rel="shortcut icon">`, or manifest.json icons, (3) Google s2 favicon endpoint. The backfill MUST follow redirects and accept `.png`, `.ico`, `.svg`, and `.jpg` icon formats.

#### Scenario: Favicon extracted from local blob
- **WHEN** a feed has a saved favicon blob in `public/favicons/` and `favicon_storage` indicates a resolvable path
- **THEN** the backfill SHALL extract theme colors from that blob and pass them to theme auto-correction logic.

#### Scenario: Homepage icon used as fallback
- **WHEN** no local favicon blob exists or extraction fails
- **THEN** the backfill SHALL fetch the feed site homepage, parse for icon links or manifest icons, fetch the icon, and attempt extraction.

#### Scenario: Google s2 fallback
- **WHEN** homepage parsing yields no usable icon
- **THEN** the backfill SHALL call the Google s2 endpoint with domain and follow redirects to fetch a favicon and attempt extraction.

### Requirement: Idempotent and safe writes
The backfill SHALL be idempotent: it MUST skip rows where `header_theme_colors.source == "auto-corrected"` and MUST only write corrected JSON when corrections are computed or when upgrading `auto` to `auto-corrected`.

#### Scenario: Skip already corrected rows
- **WHEN** a feed row has `header_theme_colors.source == "auto-corrected"`
- **THEN** the backfill SHALL skip processing it.

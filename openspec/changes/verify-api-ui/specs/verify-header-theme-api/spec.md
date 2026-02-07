## ADDED Requirements

### Requirement: Reproduce feed header color rendering
The system SHALL allow a developer to reproduce the feed header color rendering for a specified feed locally and capture the API and UI artifacts necessary for triage.

#### Scenario: Developer captures feed DB row
- **WHEN** developer runs `sqlite3 ~/.cache/quickheadlines/feed_cache.db "SELECT id,title,url,header_color,header_text_color,header_theme_colors,favicon FROM feeds WHERE title LIKE '%TechCrunch%' OR title LIKE '%Hackaday%';"`
- **THEN** the system returns the feed rows including `header_theme_colors` JSON or NULL if not set

#### Scenario: Developer captures timeline API items
- **WHEN** developer requests `/api/timeline?limit=200&offset=0`
- **THEN** the system returns JSON items where fields `feed_title`, `feed_id`, `header_theme_colors`, `header_color`, `header_text_color` are present for each item

#### Scenario: Developer captures DOM inline styles
- **WHEN** developer opens the timeline UI in a browser and inspects the feed title element
- **THEN** the developer can copy the element's outerHTML and inline `style` attributes containing `color` and `background-color`

### Requirement: Triage note
The system SHALL provide a triage note that states whether the unreadable header text is caused by server-stored colors, Elm UI application of colors, or backfill/fallback logic.

#### Scenario: Triage produces root cause
- **WHEN** developer collects DB rows, API JSON, DOM outerHTML, and backfill logs
- **THEN** the developer produces a short triage note with a recommended follow-up change: `auto-correct-unsafe-text`, `follow-301-google-fallback`, or `ui-safety-fallback`

## ADDED Requirements

### Requirement: Backfill SHALL correct existing unsafe header_text_color values
The backfill script SHALL scan all feeds and apply auto-corrections for feeds whose stored `header_theme_colors` do not contain a `text` color meeting contrast >= 4.5:1 relative to `bg`.

#### Scenario: Backfill corrects feed
- **WHEN** the backfill script runs
- **THEN** each feed with unsafe `header_theme_colors` is updated with a corrected `text` color and `header_theme_colors.source` is set to `"auto-corrected"` and the script logs the change

### Requirement: Backfill SHALL be safe in concurrent environments
The backfill SHALL avoid holding long-lived DB handles or global caches that can cause SQLite concurrency issues. It SHALL process feeds in small batches and open short-lived DB connections for writes.

#### Scenario: Backfill resilience
- **WHEN** the backfill runs in an environment with other processes accessing the DB
- **THEN** it completes without causing SQLite shared-handle crashes or deadlocks

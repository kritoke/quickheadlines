## Why

Server-side color extraction is currently incomplete and left in a WIP state (`src/color_extractor.cr`). The frontend still relies on a mixture of server-provided colors and client-side JavaScript fallbacks which creates inconsistent link/text readability across light and dark themes. Finishing the color extractor and making the server authoritative for theme-aware header text colors will remove fragile client hacks, ensure consistent WCAG-validated contrast in both themes, and improve UX across the app.

## What Changes

- Finish and validate `src/color_extractor.cr` to provide theme-aware text colors for feed headers and favicons, including WCAG contrast checks (AA 4.5:1).
- Add DB migration to store theme-aware header colors in `feeds.header_theme_colors` (JSON) and helper methods in `src/storage.cr`.
- Update fetcher (`src/fetcher.cr`) to use theme-aware extraction, validate manual overrides, and persist theme colors.
- Update API controller (`src/controllers/api_controller.cr`) to return theme-aware color fields to the frontend.
- Update Elm frontend decoders and rendering (`ui/src/Pages/Timeline.elm`, `ui/src/Pages/Home_.elm`) to use server-supplied theme-aware colors when present.
- Keep JS defensive fallbacks in `views/index.html` as a temporary non-destructive fallback.

**BREAKING**: The API will include new fields for theme-aware colors; clients that expect only the old single color field should gracefully handle the presence of the new JSON field.

## Capabilities

### New Capabilities
- `theme-aware-header-colors`: Server provides validated, theme-aware (`light` and `dark`) text colors for feed headers and favicons. Includes WCAG contrast validation and fallback generation.

### Modified Capabilities
- `feed-management`: Feed fetching and favicon/header extraction will change to persist theme-aware color metadata. (delta spec required)

## Impact

- Code:
  - `src/color_extractor.cr` (finish implementation)
  - `src/fetcher.cr` (use theme-aware extraction)
  - `src/storage.cr` (migration + helpers)
  - `src/controllers/api_controller.cr` (API response fields)
  - `ui/src/Pages/Timeline.elm`, `ui/src/Pages/Home_.elm` (decoders + rendering)
  - `views/index.html` (retain defensive fallbacks temporarily)
- DB: add `feeds.header_theme_colors` (JSON/text) column and migration path; keep backward compatibility with `feeds.header_text_color`.
- Tests: Update Playwright tests and add backend unit tests for contrast logic.
- Deployment: Run re-extraction job or migration to populate `header_theme_colors` for existing feeds; provide a safe reset script.

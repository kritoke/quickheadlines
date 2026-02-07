## Why

Some feeds in the UI display header text colors that are unreadable or fail WCAG contrast requirements even though the server-extracted theme data exists. This causes accessibility and legibility problems for users. We need a deterministic, server-side mechanism to detect unsafe `header_text_color` values, auto-correct them to accessible alternatives, and persist the correction so UIs can rely on a safe canonical source.

## What Changes

- Add server-side detection for unsafe feed header text colors (contrast < 4.5:1 for normal text) and automatically compute an accessible replacement.
- Persist the auto-corrected color in the feed record (marking the `header_theme_colors.source` or adding a small metadata flag) so clients can prefer corrected values.
- Provide a backfill script to update existing feeds in the DB with auto-corrected values where needed.
- Add unit tests for the contrast detection and auto-correction logic, and an integration test for backfill behavior.
- Update the Elm UI to prefer server-corrected text colors when `header_theme_colors.source` indicates an auto-correction, and to continue to fall back safely when no server value exists.

## Capabilities

### New Capabilities
- `header-text-auto-correction`: Server capability that validates `header_text_color` against WCAG contrast thresholds, computes a readable replacement when required, persists the result, and exposes the canonical value in `feeds` API responses.
- `backfill-header-text-corrections`: Administrative capability / script that scans feeds and applies the auto-correction for records that lack safe text colors.

### Modified Capabilities
- `feed-theme-extraction`: The existing theme extraction capability (openspec/specs/feed-theme-extraction) will be updated to include the additional requirement that extracted `header_text_color` must either meet contrast rules or be replaced with an auto-corrected value and the `source` annotated accordingly.

## Impact

- Code changes: `src/color_extractor.cr`, `src/models.cr`, `src/storage.cr` (or wherever feeds updates occur), `scripts/backfill_header_themes.cr`, and `ui/src/Pages/Timeline.elm`.
- Database: small schema/metadata addition — prefer re-using the existing `header_theme_colors.source` field (set to `"auto-corrected"`) rather than a schema migration. If a migration is required, add a lightweight migration script.
- API: `/api/feeds` and timeline endpoints will include the corrected colors in `header_theme_colors` (no breaking change to existing fields).
- Tests: new unit tests for contrast/correction and one integration/backfill test; update any existing tests that assert legacy color behavior.
- UX: clients will render more readable feed headers. The UI will still fall back to legacy colors or computed readable colors when server data is absent.

This proposal creates the concrete requirement: the server must not advertise feed header text colors that are below the WCAG 4.5:1 contrast threshold for normal text. The next artifact (design) will outline the runtime checks, the correction algorithm, and the backfill strategy.

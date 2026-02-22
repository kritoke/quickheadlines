## Why

There are user-reported mismatches where server-provided header theme colors are producing unreadable feed headers (examples: TechCrunch, Hackaday). We need a short verification effort to reproduce the behavior, confirm whether the server or Elm UI is applying unsafe text/background combinations, and gather the data necessary to decide the fix (UI-side safe-guard, server-side auto-correct, or backfill improvement).

## What Changes

- Add a small, scoped verification change that reproduces the problematic cases and captures evidence (DB rows, timeline API responses, DOM outerHTML, server logs, and backfill output).
- Create triage notes that identify whether issues are caused by: (A) server persisting unsafe colors, (B) Elm UI applying server colors without additional checks, or (C) backfill/fallback producing bad colors.
- Based on findings, propose one of the following follow-ups as a separate change: UI opt-in safety, server-side auto-correct + persist, or improved backfill/fallback handling (follow redirects or HTML <link> parsing).

## Capabilities

### New Capabilities
- `verify-header-theme-api`: a capability to reproduce and verify header_theme_colors behavior for specific feeds, collect logs, and produce a recommended remediation.

### Modified Capabilities
- None — this change is investigatory and should not change runtime behavior.

## Impact

- Code to inspect: `src/color_extractor.cr`, `scripts/backfill_header_themes.cr`, `src/models.cr`, `src/storage.cr`, `ui/src/Pages/Timeline.elm`.
- APIs: `/api/timeline` and any feed rows returned by `/api/feeds` (fields: `header_theme_colors`, `header_color`, `header_text_color`, `favicon`).
- DB: `~/.cache/quickheadlines/feed_cache.db` (feeds table rows for affected feeds).
- Tests: none required for the verification step; follow-up changes may add unit/integration tests.
- Risk: negligible — verification is read-only; do not run the backfill with writes until we confirm the remediation.

## Success Criteria

- Reproduce at least one failing case locally (TechCrunch or Hackaday) and capture:
  - DB row for the feed (id, title, header_color, header_text_color, header_theme_colors, favicon)
  - Timeline API item(s) for the feed
  - DOM outerHTML or inline styles for the rendered feed title
  - Backfill run output (if re-run)
- Produce a short triage note that identifies root cause (server vs UI vs backfill) and recommends the next change (one of the follow-ups listed above).

## Next steps (for implementer)

1. Run the server locally and collect timeline API JSON for TechCrunch and Hackaday.
2. Query the SQLite feed cache for those feeds and save the rows.
3. Inspect the UI DOM for inline styles on feed titles and capture outerHTML.
4. Optionally re-run the backfill in a non-destructive, read-only mode to observe favicon/fallback behavior.
5. Attach findings to the change and mark `verify-header-theme-api` capability as complete.

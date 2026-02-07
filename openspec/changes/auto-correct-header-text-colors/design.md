## Context

The project extracts feed theme information (background and text colors) from favicons and stores them in `feeds.header_theme_colors`. Some extracted `header_text_color` values do not meet WCAG contrast thresholds when rendered on their `header_theme_colors.bg`, resulting in unreadable feed headers in the UI. The system already has a server-side color extractor and a backfill pipeline. We will extend the server to validate and auto-correct unsafe text colors and persist the canonical corrected value.

Constraints
- Must run on existing Crystal 1.18.2 toolchain and use the nix dev wrapper for all builds.
- Avoid schema migrations where possible; prefer annotating `header_theme_colors.source` with `"auto-corrected"`.
- Backfill should be safe to run multiple times and avoid SQLite shared-handle concurrency issues.

Stakeholders: frontend (Elm) team, accessibility reviewers, and ops running backfills.

## Goals / Non-Goals

**Goals:**
- Ensure stored feed header text colors are WCAG AA compliant for normal text (contrast >= 4.5:1) relative to the feed background color.
- Provide deterministic correction logic so results are reproducible across runs.
- Persist corrections to DB and expose via API so clients can rely on server-canonical values.

**Non-Goals:**
- Do not change client-side rendering logic beyond preferring server-canonical values when present.
- Do not attempt to re-design theme extraction heuristics (ICO frame handling) in this change.

## Decisions

1) Where to correct
- Decision: Perform correction server-side during feed extraction/update and in a dedicated backfill script. Rationale: centralizes authority and avoids inconsistent client-side heuristics.

2) How to represent corrections in DB
- Decision: Reuse `header_theme_colors.source` and set value to `"auto-corrected"` when the text color was replaced. No schema migration required. Rationale: minimal DB changes; clients already read this field.

3) Correction algorithm
- Decision: Given `bg` and `text` candidates (light/dark and legacy `header_text_color`), pick the lowest-delta color that meets 4.5:1. If none of the existing candidates meet the threshold, generate a corrected color by adjusting luminance along the YIQ/relative-luminance axis toward white or black until contrast >= 4.5:1 while preserving hue (convert to HSL, adjust L). Rationale: preserves visual identity while ensuring accessibility.

4) Colors and formats
- Decision: Normalize colors to hex `#rrggbb` for storage in `header_theme_colors` and normalize `bg` to `rgb(r, g, b)` or `#rrggbb` consistent with existing values. Provide utility functions for parsing and formatting.

5) Tests
- Decision: Add unit tests for contrast computation, candidate selection, and generated color correctness. Add an integration test for the backfill script that runs against a transactional test DB.

## Risks / Trade-offs

[Risk] Auto-correcting colors may surprise users who previously customized colors.
→ Mitigation: Only set `source` to `"auto-corrected"` and do not overwrite user-specified legacy `header_text_color` fields; UIs may show an indicator that the color was auto-corrected in future work.

[Risk] Luminance adjustments could produce colors that clash with brand or look visually off.
→ Mitigation: Limit hue changes to < 5 degrees and prefer minimal luminance shifts; prefer the closest existing candidate color where possible.

[Risk] Backfill performance / DB locking
→ Mitigation: Use the existing SKIP_FEED_CACHE_INIT guard in backfill scripts, open/reuse short-lived DB connections, and process feeds in small batches.

## Migration Plan

1. Implement server-side correction in `src/color_extractor.cr` and feed update path in `src/storage.cr`.
2. Add unit tests and run `crystal spec` during CI.
3. Add `scripts/backfill_auto_correct_header_texts.cr` (or extend existing backfill) that runs safely with SKIP_FEED_CACHE_INIT and updates feeds.
4. Deploy server changes.
5. Run backfill in staging, verify results, then run in production during low-traffic window.

Rollback: To revert, restore DB from backup taken before backfill or run a reverse script that reverts `header_theme_colors` to previous `header_text_color` values if a previous snapshot is available.

## Open Questions

- Should the server persist the original `header_text_color` in a separate metadata key when auto-correcting? (Recommended: yes for auditability; low priority.)
- Should we expose a `correction_reason` (e.g., "contrast-failure") in the `header_theme_colors` metadata? (Optional.)

## Why

Many feeds in the database contain header theme colors that are unreadable (insufficient contrast) or were produced by legacy extraction flows that don't guarantee WCAG-compliant text contrast. This causes inconsistent UI presentation and accessibility problems. We need a narrowly scoped change to (1) auto-correct and upgrade theme JSON for existing feeds safely, (2) backfill the database using improved favicon extraction, and (3) ensure the Elm UI prefers and validates server-provided safe themes.

## What Changes

- Add a server-side capability to validate and auto-correct feed header theme JSON when it is saved or discovered (contrasts >= 4.5:1). This includes luminance/contrast helpers and deterministic text-role selection logic.
- Integrate auto-correction into feed storage flows so new/updated feeds are validated before write.
- Implement a robust backfill binary that:
  - iterates feed rows,
  - fetches or re-uses saved favicons (handles .png/.ico/.svg and Google s2 redirects),
  - attempts theme-aware color extraction from favicons and site homepages,
  - upgrades `header_theme_colors.source` from `auto` to `auto-corrected` when safe, or writes corrected JSON when necessary.
- Improve favicon storage: stable hashing across redirects and support for multiple file extensions.
- Elm UI adjustments so the timeline view will accept server-provided themes marked `auto` or `auto-corrected` but still verify contrast client-side and fall back when unsafe.
- Add/adjust Crystal specs and Playwright snapshot expectations where needed.

## Capabilities

### New Capabilities
- `theme-auto-correction`: Server-side validation and deterministic auto-correction of feed header theme JSON (WCAG 4.5:1). Covers API surface for theme storage, correction rules, and upgrade semantics (`auto` -> `auto-corrected`).
- `favicon-extraction-backfill`: Backfill utility and improved favicon fetching/storage. Covers logic to follow redirects, parse homepage <link rel="icon">, accept multiple favicon formats, and persist blobs to `public/favicons/` for extraction.

### Modified Capabilities
- `feeds`: (non-breaking) Storage behavior for feeds will be extended to call theme auto-correction during insert/update. No DB schema changes.

## Impact

- Code: `src/color_extractor.cr`, `src/storage.cr`, `src/favicon_storage.cr`, `scripts/backfill_auto_correct_header_texts.cr`, `bin/backfill_auto_correct_header_texts`.
- UI: `ui/src/Pages/Timeline.elm`, `ui/src/Api.elm`, `public/elm.js` (rebuilt artifact).
- Tests: Crystal specs and Playwright snapshots may need updates; new spec coverage for contrast helpers and backfill orchestration.
- Ops: Backfill should be executed in an environment with stable network access; follow-up runs may be required. Backfill is idempotent and skips rows already `auto-corrected`.
- Risk: Minimal runtime risk — no DB schema changes. Accessibility improvements may change the look of many feed headers (visual diffs in snapshots).

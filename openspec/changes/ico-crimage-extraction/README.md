Change: ico-crimage-extraction

Goal
- Add server-side support for extracting PNG frames from .ico favicons and use CrImage for image processing.

Why
- Many favicons are .ico files containing PNG frames. Current extractor only handles PNG so these feeds lack theme-aware colors.

Plan
1. Add `naqvis/crimage` to `shard.yml` dependencies.
2. Replace StumpyPNG usage in `src/color_extractor.cr` for theme-aware extraction with CrImage reading (supports ICO, PNG, JPEG, GIF).
3. Keep existing APIs and JSON shape for `header_theme_colors`.
4. Re-run backfill script to populate missing theme JSON and verify via API.

Notes
- Will keep WCAG contrast enforcement. Tests: compile project before and after changes.

## 1. Backend - Color extractor

- [ ] 1.1 Finish `src/color_extractor.cr` implementation: luminance, contrast ratio, theme-aware selection, caching helpers
- [ ] 1.2 Add unit test script `scripts/test_color_extractor.cr` (or Crystal spec) to validate WCAG math
- [ ] 1.3 Ensure `crystal build src/quickheadlines.cr` succeeds after changes

## 2. Backend - Storage & Fetcher

- [ ] 2.1 Add DB migration to create `feeds.header_theme_colors` TEXT column (non-blocking if exists)
- [ ] 2.2 Add `Storage.update_feed_theme_colors(feed_id, json)` helper in `src/storage.cr`
- [ ] 2.3 Update `src/fetcher.cr` to call theme-aware extraction and persist results; validate manual overrides

## 3. Backend - API

- [ ] 3.1 Update `src/controllers/api_controller.cr` timeline endpoints to return `header_theme_colors` (or `header_text_color_light/dark` fields)
- [ ] 3.2 Maintain backward compatibility for clients expecting `header_text_color`

## 4. Frontend

- [ ] 4.1 Update Elm decoders/models in `ui/src/Pages/Timeline.elm` and `ui/src/Pages/Home_.elm` to accept theme-aware fields
- [ ] 4.2 Render server-provided theme color based on current theme and set `data-use-server-colors="true"`

## 5. Tests & Backfill

- [ ] 5.1 Run Playwright tests and update snapshots if visual diffs are intentional
- [ ] 5.2 Implement a small backfill script to re-extract and populate `header_theme_colors` for existing feeds

## 6. Ops & Rollout

- [ ] 6.1 Add an admin endpoint or rake task to force re-extraction for a single feed
- [ ] 6.2 Deploy migration, release server, run backfill incrementally

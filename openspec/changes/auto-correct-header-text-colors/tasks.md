1. Implement server-side contrast validation and correction
   - Update `src/color_extractor.cr` to expose contrast utilities and correction function
   - Update feed update paths in `src/storage.cr` to call the correction on feed create/update
   - Add tests for contrast utilities in `spec/`

2. Add backfill script
   - Create `scripts/backfill_auto_correct_header_texts.cr` that processes feeds safely (SKIP_FEED_CACHE_INIT)
   - Ensure idempotence and logging
   - Add integration test that runs backfill against a test DB

3. Update API / Elm client
   - Ensure `/api/feeds` and timeline endpoints return `header_theme_colors` unchanged (no breaking API change)
   - Update `ui/src/Pages/Timeline.elm` to prefer server `header_theme_colors` when `source == "auto-corrected"`

4. Run tests and perform compilation check
   - Run `nix develop . --command crystal build src/quickheadlines.cr` and `nix develop . --command crystal spec`
   - Rebuild Elm and run Playwright tests if necessary

5. Backfill deployment
   - Run backfill in staging, inspect logs, and then run in production during maintenance window

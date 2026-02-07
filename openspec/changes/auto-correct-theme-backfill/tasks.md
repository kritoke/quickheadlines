1. [x] Backfill tool removed
   - The one-off backfill utility (`scripts/backfill_auto_correct_header_texts.cr`) has been removed from the repository. Runtime auto-correction and extraction remain implemented in `src/color_extractor.cr` and will correct themes progressively as feeds are fetched.

2. [ ] Verify server compile and specs
   - `nix develop . --command crystal build src/quickheadlines.cr`
   - `nix develop . --command crystal spec`

3. [ ] Run Playwright tests and update snapshots if necessary
   - `nix develop . --command npx playwright test`

4. [ ] Prepare release notes for visual changes

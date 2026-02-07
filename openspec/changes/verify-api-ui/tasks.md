## 1. Reproduce and Collect Data

- [ ] 1.1 Start the server locally using `nix develop . --command make run` and confirm it is listening on 0.0.0.0:8080
- [ ] 1.2 Run timeline API query and save items for TechCrunch and Hackaday:
      `nix develop . --command "curl -sS 'http://127.0.0.1:8080/api/timeline?limit=200&offset=0' | jq '.items[] | select(.feed_title|test("TechCrunch|Hackaday"))' > /tmp/timeline_samples.json'`
- [ ] 1.3 Query SQLite feed cache for rows and save to `/tmp/feeds_rows.sql`:
      `sqlite3 ~/.cache/quickheadlines/feed_cache.db "SELECT id,title,url,header_color,header_text_color,header_theme_colors,favicon FROM feeds WHERE title LIKE '%TechCrunch%' OR title LIKE '%Hackaday%';" > /tmp/feeds_rows.sql`
- [ ] 1.4 Inspect the UI in a browser and capture outerHTML/inline styles for at least one feed title element; save to `/tmp/dom_feed_title.html`
- [ ] 1.5 Save the last 200 lines of server logs to `/tmp/server_tail.log`

## 2. Optional Backfill Observations (Read-only)

- [ ] 2.1 Build the backfill binary in read-only/diagnostic mode:
      `nix develop . --command crystal build scripts/backfill_header_themes.cr -o bin/backfill_header_themes`
- [ ] 2.2 Run `./bin/backfill_header_themes` and save output to `/tmp/backfill_output.log` (do not allow writes to DB)

## 3. Triage & Recommendation

- [ ] 3.1 Analyze collected artifacts and determine root cause: server persistence, Elm UI application, or backfill fallback
- [ ] 3.2 Produce a short triage note summarizing findings and recommended follow-up change (one of `auto-correct-unsafe-text`, `follow-301-google-fallback`, or `ui-safety-fallback`) and attach artifacts paths

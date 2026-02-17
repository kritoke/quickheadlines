# Unreleased

This draft summarizes all notable changes made during the current release prep cycle. Review and edit before committing to the repository release notes.

## Removed

- Removed legacy/stumpy_png image-processing dead code and dependency references (see: `shard.yml`, `src/color_extractor.cr`).

## Added

- New Crystal specs for color extraction and theme-aware favicon handling (`spec/color_extractor_crimage_spec.cr`).

## Changed

- Security: Added npm override to address `cookie` package vulnerability and updated Svelte to a recent 5.x release in `frontend/package.json`.
- Frontend: Explicit SVG favicon link attribute added to the SPA template (`frontend/src/app.html`) to prevent prerender/fav lookup issues.
- Frontend: Components now treat internal placeholder icon identifiers (e.g. `internal:code_icon`) as an explicit fallback to the shipped `/favicon.svg` instead of rendering the literal placeholder. Affected components: `FeedBox.svelte`, `TimelineView.svelte`, `ClusterExpansion.svelte`.
- Backend: Serve `/favicon.ico` correctly by returning the bundled SVG with the appropriate `image/svg+xml` Content-Type and sane cache headers (`src/web/static_controller.cr`). This improves browser favicon loading behavior for some clients.
- Software feeds: Software releases use a generic internal code icon (`internal:code_icon`) as their favicon_data; UI now maps that internal token to the shipped `/favicon.svg` fallback.

## Fixed

- Fix: Browser tab favicon 404s in prerender/build caused by missing/incorrect favicon route during Svelte build.
- Fix: Various favicon handling robustness improvements (gray-placeholder detection, larger Google favicon fallback logic) — see fetcher and favicon storage logic in `src/fetcher.cr` and `src/favicon_storage.cr`.

## Tests & Verification

- Full build performed: `just nix-build` (Svelte build + Crystal binary bake) — success.
- Crystal tests: `nix develop . --command crystal spec` — 126 examples, 0 failures.
- Frontend tests: `cd frontend && npm run test` — 11 tests, all passing.

## Files touched (high level)

- Backend: `src/color_extractor.cr`, `src/fetcher.cr`, `src/web/static_controller.cr`, `src/software_fetcher.cr`, `src/web/assets.cr`
- Frontend: `frontend/src/app.html`, `frontend/src/lib/components/FeedBox.svelte`, `frontend/src/lib/components/TimelineView.svelte`, `frontend/src/lib/components/ClusterExpansion.svelte`
- Tests: `spec/color_extractor_crimage_spec.cr`

## Notes

- Commit `ec106e3` contains the favicon-related fixes (do not tag this as a release until you're ready).
- I verified build and tests locally as part of the workflow. Please review these changelog entries and adjust scope/wording before committing to your canonical CHANGELOG in the repo.

## Next steps (suggested)

1. Review this Unreleased section and edit wording or scope.
2. When satisfied, stage and commit the changelog entry: `git add changelog.md && git commit -m "chore: add Unreleased changelog"`.
3. When preparing a release, move entries from Unreleased to the release version section and tag.

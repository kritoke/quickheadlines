## Why

Several sites (InfoWorld, Network World, TechCrunch, A List Apart) stopped showing favicons after recent refactors that split favicon fetching logic into `src/fav.cr` and related files. The UI shows missing favicons; logs suggest the regression is tied to handling of `.ico` favicon files (size limits or detection). Fixing this restores visual correctness for feeds and prevents further regressions.

## What Changes

- Adjust favicon storage rules to allow larger ICO files when appropriate.
- Add targeted logging and a reproducible script to capture favicon fetch traces for failing sites.
- Add unit tests for ICO detection and size behavior; add integration check script for known failing hosts.
- If necessary, implement ICO→PNG conversion as an optional enhancement (separate follow-up change).

## Capabilities

### New Capabilities
- `favicon-debugging`: tools and scripts to reproduce and capture favicon fetch traces (scripts/check_favicons.cr and spec/fav_regression_spec.cr).

### Modified Capabilities
- `favicon-storage`: increase allowed storage for ICOs and validate magic detection for ICO files. No external API changes.

## Impact

- Code: `src/favicon_storage.cr`, `src/fav.cr`, `src/feed.cr`, `scripts/check_favicons.cr`, `spec/fav_regression_spec.cr`.
- Tests: New unit tests for ICO magic detection; integration script (network dependent) kept separate from CI.
- Dependencies: No new external runtime dependencies for the quick experiment. Optional ICO→PNG conversion (if pursued) may require an external image tool and will be a separate change.

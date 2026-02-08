## Why

The `src/fetcher.cr` file has grown beyond 1000 lines and contains multiple high-cyclomatic-complexity functions flagged by Ameba (notably favicon and feed fetching paths). This makes maintenance and further linting difficult. Splitting responsibilities into smaller files and extracting helpers will reduce complexity, improve testability, and allow targeted Ameba fixes.

## What Changes

- Split `src/fetcher.cr` into smaller, focused source files: `src/fav.cr`, `src/feed.cr`, and `src/cluster.cr` (non-API filenames kept short).
- Extract favicon-specific helpers (magic checks, fetch_favicon_uri, gray-placeholder handling, save/load helpers) into `src/fav.cr`.
- Move feed-fetching and response handling (fetch_feed, handle_feed_response, handle_success_response, retry/backoff logic) into `src/feed.cr`.
- Move clustering helpers and async orchestration (async_clustering, process_feed_item_clustering, compute_cluster_for_item) into `src/cluster.cr`.
- Add unit specs for small, pure helpers moved from `src/fetcher.cr` (parse_extracted_text_to_parsed_text, normalize_bg_value, build_header_theme_json, png_magic?, etc.).
- Create an OpenSpec change, run Ameba on the smaller files individually, and iteratively reduce CyclomaticComplexity hotspots.

**BREAKING**: None of the public APIs are intended to change; this is a pure refactor that moves internal functions into new files. Call sites remain the same.

## Capabilities

### New Capabilities
- `fav`: Encapsulates favicon fetching, validation, storage helpers and fallbacks.
- `feed`: Encapsulates feed HTTP fetching, parsing, response handling, and header extraction orchestration.
- `cluster`: Encapsulates clustering orchestration and per-feed clustering processing.

### Modified Capabilities
- None (internal refactor only)

## Impact

- Files changed: `src/fetcher.cr` will be split into `src/fav.cr`, `src/feed.cr`, `src/cluster.cr` and small helpers left in `src/utils.cr` where appropriate.
- Tests: new unit specs for moved helpers; existing specs should continue to pass.
- Build: Must run `nix develop . --command crystal build src/quickheadlines.cr` after refactor; compilation is required before marking done.
- CI: Ameba checks should be run per-file and then globally with `APP_ENV=production` for verification.

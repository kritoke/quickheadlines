# Design: elm-pages v3 + Athena Integration

This document captures the implementation plan and technical details for migrating the QuickHeadlines frontend from `elm-land` to `elm-pages` v3 and integrating `BackendTask` calls to the Athena backend.

## Overview
- Goal: Replace `elm-land` with `elm-pages` v3 while preserving the existing UX and adding a type-safe `BackendTask` for fetching news clusters from `GET /api/clusters`.
- Strategy: Hybrid rendering — prefer static generation at build time where possible, and fall back to runtime hydration (client-side) for fresh data.

## Architecture
- Rendering modes:
  - Static pre-render: run `BackendTask` during `elm-pages build` to embed snapshot HTML for the timeline pages.
  - Runtime hydration: when the page loads in the client, use `BackendTask` or a client fetch to refresh data and reconcile via Elm's update loop.
- Data flow: Athena backend -> Crystal DTOs -> JSON API `/api/clusters` -> Elm decoders -> Elm Model -> View.

## Data Mapping & Types
- Source DTO (Crystal) -> Elm mapping (examples):
  - Crystal: `NewsClusterDTO { id : Int32, headline : String, article_count : Int32, published_at : Time }`
  - Elm: `type alias Cluster = { id : Int, headline : String, articleCount : Int, publishedAt : String }`
- Decoders: place in `ui/src/Api/News.elm`; use `Json.Decode.Pipeline` or `Json.Decode` combinators. Provide robust handling for optional fields and unknown keys.
- Encoder/Client contract: the API SHALL return UTF-8 JSON with schema documented in `ui/src/Api/schema.md`.

## BackendTask Implementation
- Location: `ui/src/Backend/Clusters.elm`.
- Responsibilities:
  1. Execute `GET /api/clusters` with query params for pagination (page, limit) and filters.
  2. Retry transient failures with exponential backoff (3 attempts).
  3. Return `Result Http.Error (List Cluster)` to the caller.
- During static generation, call via `BackendTask.Http` per elm-pages v3 conventions. During client navigation use the same code path where possible to avoid duplication.

## Routing & Pages
- Route layout: port existing route names to `ui/src/Route/` per `elm-pages` conventions.
- Page entrypoints: each page lives in `ui/src/Pages/<PageName>/index.elm` exporting `get` and `Html` as required by elm-pages.

## File Structure (recommended)
- ui/
  - src/
    - Api/
      - News.elm        -- decoders + fetch helpers
    - Backend/
      - Clusters.elm    -- BackendTask implementation
    - Pages/
      - Home/
        - index.elm
    - Shared.elm
    - Theme.elm
    - Route.elm
  - elm.json

## Theme & Styling
- Reuse `Theme.elm` tokens and `elm-ui` primitives. Keep spacing, color, and typography tokens identical unless a deliberate improvement is required.
- Create `Theme/compat.elm` if small adaptors are necessary to translate old token names to new ones.

## Nix / Build & Make Changes
- Nix: add `nodejs_20` and `elm-pages` to the flake inputs and expose `npx elm-pages` in the devshell.
- Makefile targets to add/update:
  - `make elm-pages-init` — initialize `elm-pages` scaffolding in `ui/`
  - `make elm-pages-build` — `nix develop . --command "npx elm-pages v3 build --output=public"`
  - `make elm-pages-serve` — `nix develop . --command "npx elm-pages v3 serve"`
- Ensure all CI and developer docs mention the `nix develop` wrapper (see OpenSpec guidance).

## Migration Plan (high level)
1. Initialize `elm-pages` scaffolding (`make elm-pages-init`).
2. Implement `Theme.elm` and shared layout in `ui/src/Shared.elm`.
3. Implement `BackendTask` and decoders (`Api/News.elm`, `Backend/Clusters.elm`).
4. Port the Home page and critical components to `Pages/Home`.
5. Run `elm-pages build` and compare rendered output to previous site; adjust CSS/tokens to match visual regression tolerances.
6. Remove `elm-land` build targets and move source files to `archive/elm-land/` with a migration note.

## Testing
- Unit tests: `elm-test` for decoders, pure view helpers, and small business logic.
- Integration tests: smoke tests with `elm-pages v3 test` and Playwright snapshots for key pages (update snapshots if deliberate visual changes occur).
- Acceptance criteria: pages render without decoder errors, clusters API returns expected shapes in staging, and no regressions in Playwright snapshots beyond accepted tolerances.

## CI / Deployment
- CI steps:
  1. `nix develop . --command make elm-pages-build`
  2. Run `elm-test` and Playwright tests
  3. Publish `public/` or `dist/` to the artifact store
- Production: use optimized build `npx elm-pages v3 build --optimize` and serve static files. If dynamic mode required, deploy with Node support.

## Rollback & Compatibility
- Keep `archive/elm-land/` with instructions for restoring previous build targets.
- Feature-flag the new frontend in deployment (if possible) to switch back quickly.

## Performance & Error Handling
- Minimize runtime hydration by pre-rendering pages where possible.
- BackendTask should retry transient errors and surface permanent errors to Sentry/monitoring.

## Acceptance Criteria
1. `elm-pages v3 build` completes successfully in CI and produces `public/elm.js` and HTML pages.
2. `BackendTask` returns typed `Cluster` values and pages render without decoder/runtime errors.
3. Visual regressions limited to approved differences; Playwright snapshots updated and committed.

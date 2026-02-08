# Implementation Tasks

Below is a proposed, prioritized checklist to implement the `elm-pages v3` migration. Each item includes a short description, an estimate, dependencies, and verification steps.

- [ ] 1.0 Initialize `elm-pages` scaffold (make target)
  - Estimate: 1d
  - Description: Add `elm.json` and minimal `elm-pages` project structure under `ui/` and a Makefile target `make elm-pages-init` that bootstraps the project.
  - Dependencies: none
  - Verify: run `nix develop . --command make elm-pages-init` then `nix develop . --command make elm-pages-build` and confirm `public/elm.js` is produced without errors

- [ ] 2.0 Add Theme and shared layout
  - Estimate: 1d
  - Description: Port `Theme.elm` tokens and `Shared.elm` layout into `ui/src/` so components can import `Theme.semantic` and layout primitives.
  - Dependencies: 1.0
  - Verify: compile with `make elm-pages-build` and visually compare the home layout; unit test `Theme` helpers with `elm-test`

- [ ] 3.0 Implement `BackendTask` for clusters
  - Estimate: 2d
  - Description: Create `ui/src/Backend/Clusters.elm` to fetch `GET /api/clusters` with pagination, retries, and decoders in `ui/src/Api/News.elm`.
  - Dependencies: 1.0, 2.0
  - Verify: run `elm-pages build` (static generation path) and run integration in dev serve; decoders covered by `elm-test`

- [ ] 4.0 Port Home page and feed components
  - Estimate: 3d
  - Description: Migrate critical pages (Home timeline, cluster view) into `ui/src/Pages/` and use `BackendTask`/Api decoders for data.
  - Dependencies: 2.0, 3.0
  - Verify: pages render and show clusters; run Playwright snapshot tests and update snapshots if intentional

- [ ] 5.0 Update Nixflake and Makefile targets
  - Estimate: 0.5d
  - Description: Add `nodejs_20` and `elm-pages` to the flake inputs; add `make` targets: `elm-pages-init`, `elm-pages-build`, `elm-pages-serve`.
  - Dependencies: 1.0
  - Verify: CI `make elm-pages-build` passes locally in the nix devshell

- [ ] 6.0 CI integration and tests
  - Estimate: 1d
  - Description: Add `elm-test` and Playwright steps for the new frontend; ensure tests run in `nix develop` devshell.
  - Dependencies: 4.0, 5.0
  - Verify: `nix develop . --command npx playwright test` passes or snapshots are intentionally updated

- [ ] 7.0 Archive `elm-land` artifacts
  - Estimate: 0.5d
  - Description: Move old `elm-land` sources to `archive/elm-land/`, remove `elm-land` build targets, and add a migration note with rollback instructions.
  - Dependencies: 4.0, 6.0
  - Verify: repository no longer builds `elm-land` artifacts; `make` targets reference `elm-pages` only

- [ ] 8.0 Documentation and release notes
  - Estimate: 0.5d
  - Description: Update `README.md` developer docs with `nix develop` commands for `elm-pages`, and add release notes describing compatibility and rollback steps.
  - Dependencies: 5.0, 7.0
  - Verify: developer docs contain `make` and `nix develop` examples; peers can follow steps to run locally

- [ ] 9.0 Final review + PR
  - Estimate: 0.5d
  - Description: Prepare a PR that includes the `ui/` scaffold, `Theme`, `BackendTask`, updated Makefile/Nix, and automated tests. Request reviews and address feedback.
  - Dependencies: all above
  - Verify: PR CI passes and reviewers approve

Notes:
- Run all build/test commands inside the nix devshell (see `openspec/AGENTS.md`):
  - Example: `nix develop . --command make elm-pages-build`
- If you'd like, I can create a first-pass `Makefile` targets and the minimal `elm-pages` scaffold in `ui/` for PR preparation.

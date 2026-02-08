# Proposal: migrate-to-elm-pages-v3

## Summary
Migrate the QuickHeadlines (Lumnitide) frontend from the deprecated `elm-land` framework to `elm-pages` v3. This transition resolves toolchain deprecation errors and introduces `BackendTask` for high-performance data fetching from the Athena backend.

## Motivation
- **Technical Debt:** `elm-land` is throwing significant deprecation errors in the current Nix shell environment.
- **Performance:** `elm-pages` v3 allows pre-rendering of news clusters and type-safe integration with the Crystal DTOs.
- **Standardization:** Aligns with "The Brain" infrastructure standards for 2026.

## Scope
- Initialize `elm-pages` v3 in the `ui/` directory.
- Port existing `elm-ui` styling and `Theme.semantic` hooks.
- Implement `BackendTask` logic to fetch news clusters from `GET /api/clusters`.
- Decommission the old `elm-land` files.

## Impact
- **Breaking Change:** The routing structure will shift from `Pages/` to `Route/`.
- **Infrastructure:** Requires `nodejs_20` and `elm-pages` in the Nix flake.

## Timeline
- **Phase 1:** Initialize `elm-pages` v3 and migrate styling (1 week).
- **Phase 2:** Implement `BackendTask` and port routing logic (2 weeks).
- **Phase 3:** Test and deploy (1 week).

## Risks
- **Toolchain Complexity:** `elm-pages` v3 introduces new concepts like `BackendTask`.
- **Time Estimate:** Underestimating the migration effort could delay the project.

## Alternatives
- **Stick with `elm-land`:** Risk of toolchain breakage and lack of performance optimizations.
- **Use `elm-spa`:** Less standardized and requires more manual setup.

## Conclusion
Migrating to `elm-pages` v3 is the best path forward, balancing technical debt resolution with performance gains and standardization.
## Context

The current `run` target in the makefile always executes `elm-land-build`, which installs elm-land via npm and potentially other dependencies like Tailwind CSS CLI. On FreeBSD, where Node.js/npm may not be available or desired, this causes build failures. FreeBSD deployments are designed to use pre-compiled `public/elm.js` files to avoid requiring Elm/Node.js toolchain.

## Goals / Non-Goals

**Goals:**
- Prevent unnecessary npm package installations during FreeBSD development builds
- Maintain existing behavior for platforms that have Elm/Node.js available
- Ensure FreeBSD dev mode works with pre-compiled Elm bundles

**Non-Goals:**
- Modify production build process
- Change how other platforms handle Elm compilation
- Remove elm-land dependency entirely (still needed for platforms with Node.js)

## Decisions

**Decision 1: Conditional elm-land-build execution**
Similar to the existing `elm-build` target, modify the `run` target to check for FreeBSD platform and existing `public/elm.js` before executing `elm-land-build`.

**Rationale:** The `elm-build` target already implements this pattern successfully for production builds. Applying the same logic to development mode ensures consistency and avoids redundant npm operations.

**Alternatives considered:**
- Remove elm-land-build from run entirely: Rejected because other platforms still need Elm compilation
- Always use pre-compiled elm.js: Rejected because it would break development on platforms with Elm available

**Decision 2: Platform detection via existing makefile variables**
Use the existing `$(OS_NAME)` and file existence checks rather than introducing new environment variables.

**Rationale:** The makefile already has robust platform detection and file checking logic used in `elm-build`. Reusing this maintains consistency and reduces complexity.

## Risks / Trade-offs

**Risk: Outdated elm.js in development**
If `public/elm.js` exists but is outdated on FreeBSD, developers won't get automatic rebuilds during development.

**Mitigation:** Document that FreeBSD development requires manual elm.js updates from CI/other platforms. This is acceptable since FreeBSD lacks Elm toolchain anyway.

**Risk: Inconsistent dev experience**
FreeBSD developers have different workflow (manual elm.js updates) vs other platforms (automatic compilation).

**Mitigation:** This is already the case due to FreeBSD's Node.js avoidance. The documentation already covers this difference.</content>
<parameter name="filePath">openspec/changes/fix-freebsd-dev-tailwind/design.md
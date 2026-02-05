## Why

During FreeBSD development mode builds, the `run` target executes `elm-land-build` which installs elm-land via npm, potentially installing Tailwind CSS CLI unnecessarily. Since FreeBSD deployments use pre-compiled `public/elm.js`, this npm installation is redundant and causes deployment issues on systems without Node.js/npm.

## What Changes

- Modify the `run` target in makefile to conditionally skip `elm-land-build` on FreeBSD when `public/elm.js` exists
- Ensure FreeBSD dev mode uses pre-compiled Elm bundle instead of rebuilding with elm-land

## Capabilities

### New Capabilities
<!-- No new capabilities introduced -->

### Modified Capabilities
<!-- No existing spec-level requirements are changing -->

## Impact

- Makefile build system (run target modification)
- FreeBSD development workflow (skips unnecessary npm installations)
- No impact on production builds or other platforms</content>
<parameter name="filePath">openspec/changes/fix-freebsd-dev-tailwind/proposal.md
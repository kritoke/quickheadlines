## Why

The `src/color_extractor.cr` module currently contains several large, high‑cyclomatic‑complexity functions that trigger Ameba linter failures and make the code harder to read and maintain. Reducing complexity by extracting smaller helpers will address the linter findings, improve testability, and reduce risk of future bugs. This is timely because an earlier low‑risk linting pass removed many minor issues; focused refactoring on `color_extractor` is the next highest‑value item.

## What Changes

- Refactor `src/color_extractor.cr` to extract parsing, candidate building, image handling (ICO vs generic), and selection logic into small private helper methods.
- Reduce CyclomaticComplexity for the remaining public methods by delegating branches to helpers and adding guard clauses.
- Fix remaining Naming/BlockParameterName and Style findings in the file (rename single‑letter block params, remove redundant returns, simplify `unless` negations).
- Add small unit tests for newly extracted helpers where practical to lock behavior during refactor.
- Save updated Ameba output to `openspec/changes/fix-ameba-color-extractor-refactor/ameba-output-post-refactor.txt` after the refactor.

**BREAKING:** None expected — changes are internal refactors and private helper extractions that preserve public APIs.

## Capabilities

### New Capabilities
- `refactor-color-extractor`: encapsulates the refactor work, its tests, and verification steps.

### Modified Capabilities
- None — this change is an internal refactor and does not change external behavior or API contracts.

## Impact

- Affected code: `src/color_extractor.cr`, tests adjacent to color extraction (if present), and Ameba linter output artifacts in `openspec/changes/...`.
- APIs: No external API surface changes expected; all modifications are private implementation refactors.
- Dependencies: No new runtime dependencies. Development tasks will run Ameba and Crystal compile checks inside the project's nix devshell.
- CI: Ameba linter runs (CI) should show a reduced number of Metrics/CyclomaticComplexity failures; tests and `crystal build` must continue to succeed before marking the change complete.

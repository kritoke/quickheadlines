## Why

The QuickHeadlines codebase has accumulated technical debt through Ameba linter violations, TypeScript errors, and code complexity issues that impact maintainability and developer experience. Addressing these issues will improve code quality, reduce bugs, and establish better coding patterns for future development.

## What Changes

- Fix 43 Ameba linter violations in Crystal backend code
- Resolve 25 TypeScript/Svelte type checking errors in frontend code  
- Reduce cyclomatic complexity in high-complexity methods
- Replace unsafe `not_nil!` usage with proper nullability handling
- Fix redundant code patterns and unused variables
- Standardize return types and naming conventions
- Apply consistent code formatting across the codebase

## Capabilities

### New Capabilities
- `code-quality-standards`: Establish consistent code quality standards and automated checking for both Crystal backend and Svelte frontend

### Modified Capabilities

## Impact

- All Crystal source files in `src/` directory
- Frontend Svelte components and TypeScript files in `frontend/src/`
- Build and test infrastructure (linting, type checking scripts)
- Developer workflow (pre-commit hooks, CI pipeline)
- No breaking API changes to end users
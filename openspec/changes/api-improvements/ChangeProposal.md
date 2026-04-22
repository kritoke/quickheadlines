# Change Proposal: API Improvements

## Summary

This change implements several improvements to the QuickHeadlines project to enhance API design, test coverage, and code quality tool:

### Motivation

- **Pagination**: The UX - Timeline currently loads 500 items then client filters. Switching to server-side pagination ( dramatically improve initial load time and memory usage
- **Testing**: No automated API tests exist, making refactoring risky
- **Type Safety**: Frontend types aren't validated against backend DTO
- **Code Quality**: Some dead code and missing pre-commit hooks would catch issues earlier

### Proposed Changes

1. **Backend Pagination**
   - Add cursor-based pagination to `/api/timeline` endpoint
   - Frontend consumes cursor for infinite scroll
   - Response time: ~50ms initial vs 2-3 seconds for 500 items

2. **API Test Suite**
   - Add specs for `/api/feeds`, `/api/timeline`, `/api/clusters`
   - Add integration tests for API lifecycle

3. **Type Generation**
   - Add script to generate TypeScript types from Crystal DTOs
   - Run as part of `just nix-build`

4. **Pre-commit Hooks**
   - Add git hooks for linting and type checking
   - Run via `just lint` or `just nix-build`

### Files Affected

- `src/controllers/api_controller.cr` - Timeline endpoint
- `spec/api/` - New test directory
- `frontend/src/lib/api.ts` - Add pagination support
- `frontend/src/lib/types/` - Generated types
- `justfile` - Add lint target

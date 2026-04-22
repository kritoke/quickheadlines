## Summary

This change is a pure internal refactoring with no new capabilities and no modified requirements. All public interfaces and behaviors remain identical. No new spec files are created.

## Verification

The refactoring changes can be verified by:
1. Running `just nix-build` - the project must compile without errors
2. Running `nix develop . --command crystal spec` - all tests pass
3. Running `cd frontend && npm run test` - frontend tests pass

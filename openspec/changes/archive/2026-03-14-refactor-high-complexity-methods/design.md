## Context

The QuickHeadlines codebase has accumulated technical debt in the form of high cyclomatic complexity methods. Ameba linting identified 12 methods with complexity scores ranging from 13-22, well above the recommended threshold of 12. These methods are primarily in the feed fetching, favicon handling, clustering, and API controller modules. The current state makes these areas difficult to test, debug, and maintain.

**Current State:**
- Methods with 13-22 cyclomatic complexity
- Nested conditionals and multiple responsibilities per method
- Some methods exceed 500 lines of code
- Mixed concerns (e.g., data fetching, validation, error handling, caching all in one method)

**Constraints:**
- Must maintain backward compatibility - no breaking changes
- All refactoring must pass existing tests
- Performance should not be negatively impacted
- Must work within Crystal 1.18.2 limitations

## Goals / Non-Goals

**Goals:**
- Reduce cyclomatic complexity of all flagged methods to ≤12
- Improve code readability and maintainability
- Enable better test coverage for individual components
- Follow SOLID principles and single responsibility principle
- Maintain or improve performance characteristics
- Pass all Ameba linting rules

**Non-Goals:**
- Changing external APIs or behavior
- Adding new features or capabilities
- Major architectural redesigns
- Modifying database schema or data models
- Changing frontend functionality

## Decisions

### 1. Extract Method Pattern vs. Complete Rewrite
**Decision**: Use extract method pattern to incrementally refactor
**Rationale**: Safer approach that maintains existing behavior while improving structure. Complete rewrites risk introducing bugs and require more extensive testing.

### 2. Private Helper Methods vs. Separate Classes
**Decision**: Start with private helper methods, consider separate classes for reusable logic
**Rationale**: Most of the complex logic is specific to each module. Private helpers provide immediate complexity reduction without over-engineering. If patterns emerge across modules, we can extract shared utilities later.

### 3. Preserve Existing Error Handling
**Decision**: Maintain identical error handling and logging behavior
**Rationale**: Error handling is critical for production stability. Any changes to error paths could hide important issues or break monitoring.

### 4. Focus on High-Impact Methods First
**Decision**: Prioritize methods with complexity >15 first
**Rationale**: These provide the biggest immediate benefit and are most likely to contain bugs. Methods with complexity 13-14 can be addressed later if needed.

### 5. Automated Testing Strategy
**Decision**: Rely on existing test suite + add targeted unit tests for extracted methods
**Rationale**: Existing integration tests ensure overall behavior remains correct. New unit tests for extracted methods ensure the refactored components work correctly in isolation.

## Risks / Trade-offs

**[Risk] Introduced bugs during refactoring** → Mitigation: Run full test suite after each change, use git commits to track incremental changes, verify with `just nix-build`

**[Risk] Performance regression from additional function calls** → Mitigation: Profile before/after, Crystal's optimizer should handle simple function calls efficiently, focus on algorithmic improvements where possible

**[Risk] Over-engineering with too many small methods** → Mitigation: Keep extracted methods focused and meaningful, avoid creating methods that are only called once from a single location

**[Risk] Incomplete refactoring leaving some complexity** → Mitigation: Run Ameba after each refactoring session to verify complexity reduction, ensure all flagged methods are addressed

## Migration Plan

1. **Phase 1**: Address auto-fixable issues (useless assignment)
2. **Phase 2**: Refactor highest complexity methods (>15 complexity)
3. **Phase 3**: Address moderate complexity methods (13-14 complexity)
4. **Phase 4**: Verify all changes with Ameba, tests, and build process
5. **Rollback**: Each phase is independently reversible via git commits

## Open Questions

- Should we extract common favicon handling logic into a dedicated service?
- Are there opportunities to use Crystal's `Result` type more extensively for error handling?
- Should we consider implementing a facade pattern for the clustering service?
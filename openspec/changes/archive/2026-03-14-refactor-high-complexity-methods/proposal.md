## Why

The QuickHeadlines codebase contains multiple methods with high cyclomatic complexity (ranging from 13-22), exceeding the recommended threshold of 12. These complex methods are difficult to maintain, test, and debug, increasing the risk of bugs and making future development slower. Addressing these issues now will improve code quality, reduce technical debt, and make the codebase more maintainable.

## What Changes

- Refactor `scripts/backfill_header_themes.cr` main function (complexity 22) into smaller, focused functions
- Break down `src/fetcher/favicon.cr` fetch_favicon_uri method (complexity 20) by extracting conditional logic
- Separate `src/fetcher/feed_fetcher.cr` fetch method (complexity 19) into feed-type specific handlers
- Extract responsibilities from `src/fetcher/refresh_loop.cr` refresh_all method (complexity 17)
- Simplify `src/services/clustering_service.cr` compute_cluster_for_item method (complexity 15)
- Reduce complexity in API controller methods with moderate complexity (13-14)
- Remove useless assignment in `src/favicon_storage.cr` (auto-fixable lint issue)

## Capabilities

### New Capabilities
- `code-quality`: Establishes code quality standards and refactoring guidelines for maintaining low cyclomatic complexity
- `favicon-handling`: Improves favicon fetching and processing with better separation of concerns

### Modified Capabilities
- None - this change focuses on implementation improvements without altering external behavior or requirements

## Impact

- Affected files: scripts/backfill_header_themes.cr, src/fetcher/favicon.cr, src/fetcher/feed_fetcher.cr, src/fetcher/refresh_loop.cr, src/services/clustering_service.cr, src/controllers/api_controller.cr, src/favicon_storage.cr
- No API changes or breaking changes - purely internal refactoring
- Improved testability and maintainability of core functionality
- Reduced cognitive load for developers working with these modules
- Better adherence to Crystal best practices and Ameba linting standards
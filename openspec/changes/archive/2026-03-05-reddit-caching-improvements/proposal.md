## Why

The Reddit feed caching implementation has several issues identified in code review:
1. 304 responses don't capture updated ETag/Last-Modified headers from the response
2. HTTP requests lack timeouts, potentially hanging indefinitely
3. Redundant variable assignment reduces code clarity
4. High cyclomatic complexity triggers Ameba warnings
5. Duplicate header construction code across methods

These issues could cause cache invalidation problems, hanging requests, and maintenance difficulties.

## What Changes

- Fix 304 response handling to capture updated cache headers from Reddit's response
- Add HTTP timeouts (10s connect, 30s read) consistent with the rest of the codebase
- Extract helper methods to reduce cyclomatic complexity and code duplication
- Remove redundant variable assignment
- Improve nil safety in title handling

## Capabilities

### New Capabilities
- `reddit-caching-improvements`: Improve Reddit feed caching with proper timeout handling, updated header capture, and code quality improvements

### Modified Capabilities
- None - this is an internal improvement that doesn't change user-facing behavior

## Impact

- **Code**: `src/fetcher_adapter.cr` - add helper methods, fix timeout handling, improve code quality
- **Reliability**: Prevents hanging requests with proper timeouts
- **Maintainability**: Reduces cyclomatic complexity and code duplication

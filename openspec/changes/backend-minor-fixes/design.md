## Context

Code review identified several small but impactful issues: an incorrect MIME type mapping, overly broad exception handling that masks bugs, silent error swallowing, inconsistent timeout values, and divergent IP extraction logic. These are individually minor but collectively reduce code quality and debuggability.

## Goals / Non-Goals

**Goals:**
- Fix the `.woff` MIME type typo
- Make error handling precise and logged
- Use centralized timeout constants
- Consistent IP extraction across HTTP and WebSocket

**Non-Goals:**
- Changing timeout values themselves (only where they're defined)
- Adding new error handling patterns
- Modifying the rate limiter or auth system behavior

## Decisions

### D1: Narrow rescue in check_admin_auth

Change `rescue Exception` to `rescue ArgumentError`. The purpose of the rescue is to handle timing-safe byte comparison edge cases, which raise `ArgumentError`. Catching all `Exception` masks programming errors like `NilAssertionError`.

### D2: Log shutdown errors in AppBootstrap

Change `rescue nil` to `rescue ex` with `Log.for("AppBootstrap").warn { "Error closing database: #{ex.message}" }`. Shutdown errors should be visible for debugging.

### D3: Extract shared IP extraction

Move the `TRUSTED_PROXY`-aware IP extraction logic from `ApiBaseController.client_ip` to a shared location in `Utils`. Both `quickheadlines.cr` (WebSocket) and `ApiBaseController` call the shared method.

## Risks / Trade-offs

- **[Narrowing rescue could miss edge cases]** → Only `ArgumentError` is expected from byte comparison. If other error types occur, they will now surface instead of being silently swallowed, which is the desired behavior.
- **[Shared IP extraction changes behavior]** → WebSocket connections will now respect `TRUSTED_PROXY` and `X-Forwarded-For`, which is more correct.

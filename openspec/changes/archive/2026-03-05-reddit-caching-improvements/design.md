## Context

The Reddit feed caching implementation in `src/fetcher_adapter.cr` works but has quality issues:

1. **304 header handling**: When Reddit returns 304, we return the old ETag/Last-Modified instead of checking for updated values in the response
2. **No timeouts**: HTTP::Client.get() has no timeout, can hang indefinitely
3. **Code complexity**: Methods exceed Ameba's cyclomatic complexity threshold (13/12)
4. **Duplication**: Header construction is duplicated between JSON and RSS methods

The rest of the codebase uses:
- Connect timeout: 10 seconds (src/config.cr, src/utils.cr)
- Read timeout: 30 seconds (src/config.cr, src/utils.cr)

## Goals / Non-Goals

**Goals:**
- Capture updated cache headers from 304 responses
- Add proper HTTP timeouts consistent with codebase
- Reduce cyclomatic complexity below Ameba threshold
- Remove code duplication
- Improve nil safety

**Non-Goals:**
- Not changing caching behavior or user-facing functionality
- Not adding new features

## Decisions

1. **Use codebase-standard timeouts**: 10s connect, 30s read - matches existing HTTP config
2. **Extract three helper methods**:
   - `build_reddit_headers(etag, last_modified)` - constructs HTTP headers with caching
   - `handle_reddit_304(response, etag, last_modified)` - handles 304 with header capture
   - `reddit_http_client(url)` - creates client with timeouts
3. **Log 304 hits at DEBUG level** - consistent with existing debug logging pattern
4. **Improve nil safety** - use `try(&.as_s?) || "Untitled"` pattern for titles

## Risks / Trade-offs

- [Risk] Reddit may not send updated headers on 304 → **Mitigation**: Fall back to existing headers if response lacks them
- [Risk] 10s connect timeout may be too short for slow networks → **Mitigation**: Matches existing codebase defaults, can be adjusted later if needed

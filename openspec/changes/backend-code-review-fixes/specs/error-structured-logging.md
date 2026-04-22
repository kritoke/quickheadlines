# error-structured-logging

**Owner:** Backend Team  
**Status:** proposed

## Overview

Replace all `STDERR.puts` logging with Crystal's built-in `Log` module for structured, level-aware, filterable logging.

## Requirements

### REQ-001: Subsystem Loggers
Application code uses `Log.for("quickheadlines.<subsystem>")` loggers:

| Subsystem | Source Files |
|-----------|-------------|
| `quickheadlines.storage` | `database.cr`, `feed_cache.cr`, `cache_utils.cr`, `clustering_repo.cr`, `cleanup.cr`, `header_colors.cr` |
| `quickheadlines.clustering` | `clustering_service.cr`, `clustering_engine.cr` |
| `quickheadlines.feed` | `feed_fetcher.cr`, `refresh_loop.cr`, `feed_repository.cr` |
| `quickheadlines.http` | `proxy_controller.cr`, `api_base_controller.cr` |
| `quickheadlines.app` | `app_bootstrap.cr`, `application.cr`, `quickheadlines.cr` |
| `quickheadlines.websocket` | `socket_manager.cr`, `event_broadcaster.cr` |

### REQ-002: Log Levels
- `Log.error` — failures that prevent operations (DB errors, clustering crashes)
- `Log.warn` — recoverable issues (rate limit hit, feed fetch failed)
- `Log.info` — significant events (server start, migration run, cache cleared)
- `Log.debug` — verbose operational detail (only active when `config.debug?`)

### REQ-003: Structured Fields
Log messages use metadata for key data:
```crystal
Log.for("quickheadlines.storage").info { {path: @db_path, event: "initialized"} }
Log.for("quickheadlines.clustering").info { {item_count: processed, cluster_count: rep_map.size} }
```

### REQ-004: Exception Logging
All `rescue` blocks that log errors include the exception:
```crystal
Log.for("quickheadlines.storage").error(exception: ex) { {message: "Migration failed"} }
```

### REQ-005: Migration from STDERR.puts
All `STDERR.puts "[timestamp] message"` patterns are replaced with appropriate `Log` calls. `STDERR.puts` is not used for application logging.

## Acceptance Criteria

- [ ] Zero `STDERR.puts` calls in application code (excluding third-party shards)
- [ ] Each subsystem uses its own `Log.for("quickheadlines.<subsystem>")`
- [ ] `Log` configuration is initialized at application startup
- [ ] Exception logging includes backtrace via `exception: ex`

## Affected Files

All `.cr` files — replace `STDERR.puts` with `Log.for(...)`.

## Non-Affected

- `crystal-mcp` tool (not application code)
- Third-party shards (athena, etc.)

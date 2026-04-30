# General — Task Context

**Last Updated:** 2026-04-30
**Status:** Active
**Next Task ID:** TP-004

---

## Current State

This is the default task area for quickheadlines. Tasks that don't belong
to a specific domain area are created here.

Taskplane is configured and ready for task execution. Use `/orch all` for
parallel batch execution or `/orch <path/to/PROMPT.md>` for a single task.

### Active Batch: SQLite & Fetch Stability

Three tasks addressing feed fetching failures after a few hours of runtime:

1. **TP-001** (L) — Fix SQLite database contention & locking (root cause)
2. **TP-002** (M) — Harden feed fetch against hangs & semaphore exhaustion
3. **TP-003** (S) — Fix refresh loop shutdown logic

Wave plan: Wave 1 → TP-001, Wave 2 → TP-002 + TP-003 (parallel)

---

## Key Files

| Category | Path |
|----------|------|
| Tasks | `taskplane-tasks/` |
| Config | `.pi/taskplane-config.json` |
| Feed Config | `feeds.yml` |
| Source | `src/` |
| Tests | `spec/` |
| Frontend | `frontend/` |
| Logs | `qh.log`, `server.log`, `server_debug.log` |

## Architecture

- **Language:** Crystal (>= 1.18.0) with Athena web framework
- **Database:** SQLite3 (WAL mode) via crystal-sqlite3 + crystal-db
- **Frontend:** Svelte 5 embedded via BakedFileSystem
- **Build:** `just nix-build` (uses nix flake for Crystal toolchain)
- **Dependencies:** Managed in `shard.yml` / `shard.lock`

## Conventions

- Crystal code style with `ameba` linter
- Structured logging via `Log.for("quickheadlines.*")`
- Constants in `src/constants.cr`
- Feature modules under `src/` organized by domain (fetcher, storage, services, etc.)

## Tech Debt & Known Issues

_Items discovered during task execution are logged here by agents._

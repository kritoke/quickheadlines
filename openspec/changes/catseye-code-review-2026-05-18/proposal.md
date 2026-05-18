# Catseye Code Review — 2026-05-18

This OpenSpec Change captures the results of a focused Catseye scan (flat taint engine, ai_lint + claws enabled) run on 2026-05-18. The previous scan (2026-05-17, CFG mode) addressed SSRF, timeout, path traversal, and open redirect issues. This scan focuses on remaining correctness, reliability, and maintainability issues.

## Objective

- Triage all remaining findings from the latest scan
- Identify genuine issues vs false positives
- Create actionable tasks for real issues
- Document false positives in `planning/catseye-false-positives-2026-05-18.md`

## Scan Summary

- **Files scanned:** 67
- **Nodes:** 7,237
- **Errors:** 226
- **Warnings:** 268
- **Engine:** flat (default)

### Top Categories by Count

| Category       | Count |
| -------------- | ----- |
| LongMethod     | 173   |
| MagicNumber    | 68    |
| LargeClass     | 62    |
| DeepNesting    | 36    |
| ShotgunSurgery | 31    |
| DeadCode       | 19    |
| OrphanedSpawn  | 17    |
| AntiSingleton  | 12    |
| FeatureEnvy    | 11    |
| LazyClass      | 10    |
| Blob           | 9     |
| SpaghettiCode  | 9     |

## Triage Results

### Real Issues (Worth Fixing)

| #   | Severity | Finding                          | File                                       | Details                                                          |
| --- | -------- | -------------------------------- | ------------------------------------------ | ---------------------------------------------------------------- |
| 1   | Critical | **PathTraversal**                | `src/config/loader.cr:4`                   | `File.read(path)` with variable argument — only security finding |
| 2   | Critical | **DeadLetter**                   | `src/services/database_service.cr:40`      | Channel `@db` closed before receive — sender gets `ClosedError`  |
| 3   | Critical | **MutedPack**                    | `src/websocket/event_broadcaster.cr:59`    | `SHUTDOWN_CHANNEL` send with no consumer — messages lost         |
| 4   | Error    | **OrphanedSpawn** (17 instances) | Multiple files                             | Spawned fibers with no `rescue/ensure` — die silently            |
| 5   | Error    | **HighComplexity**               | `src/fetcher/refresh_loop.cr:308`          | `start_refresh_loop` cyclomatic complexity **32**                |
| 6   | Error    | **DeepNesting**                  | `src/fetcher/refresh_loop.cr:308`          | `start_refresh_loop` nesting depth **23**                        |
| 7   | Error    | **LongMethod** (774 nodes)       | `src/fetcher/refresh_loop.cr:308`          | `start_refresh_loop` is enormous                                 |
| 8   | Error    | **GodObject/Blob**               | `src/fetcher/feed_fetcher.cr:16`           | `FeedFetcher` has 30 methods                                     |
| 9   | Error    | **DRYViolation**                 | `src/dtos/story_dto.cr:35`                 | 34 duplicate blocks — massive copy-paste                         |
| 10  | Error    | **LongParameterList**            | `src/services/favicon_sync_service.cr:130` | `categorize_backfill` has **8 params**                           |
| 11  | Error    | **DeadCode** (19 instances)      | Multiple controllers                       | Unreachable code after `return`/`raise`                          |
| 12  | Warning  | **DataClump** (7 groups)         | Multiple files                             | Repeated parameter pairs need structs                            |

### False Positives (See `planning/catseye-false-positives-2026-05-18.md`)

- **LargeClass** (~60 findings): Scanner bug — Crystal modules cause inflated line counts (999k+)
- **MagicNumber** (68 findings): HTTP status codes like 401, 404, 429 are self-explanatory
- **DeadCode** (19 findings): Athena framework macros cause unreachable code detection
- **AntiSingleton** (12 findings): Crystal class variables are idiomatic for module-level state
- **ShotgunSurgery/Log** (31 findings): Calling `Log` frequently is normal
- **LazyClass** (10 findings): Single-method controllers are idiomatic in Athena
- **FeatureEnvy** (11 findings): Can't extend Crystal stdlib `URI` easily
- **Most DeepNesting/HighComplexity**: Crystal `case/when` is flat pattern matching, not nested branching

## References

- `planning/catseye-false-positives-2026-05-18.md` (this scan's FP document)
- `planning/catseye-false-positives.md` (previous scan's FP document)
- `openspec/changes/catseye-scan-2026-05-17/` (previous scan's OpenSpec change)

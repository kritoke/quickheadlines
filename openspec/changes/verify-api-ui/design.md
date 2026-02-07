## Context

The project introduced server-side extraction of theme-aware header colors and an Elm UI that prefers server-provided `header_theme_colors` when present. Users reported feeds where the rendered header text was unreadable (examples: TechCrunch, Hackaday). The goal of this change is not to modify behavior yet but to methodically reproduce and gather evidence to determine the root cause.

Constraints:
- Must follow existing OpenSpec workflow (this is an investigatory change).
- Do not modify production data or run backfill writes until root cause is known.

## Goals / Non-Goals

**Goals:**
- Reproduce failing cases locally (TechCrunch, Hackaday) in both API and UI.
- Collect artifacts: DB feed rows, timeline API JSON, DOM outerHTML/inline styles, server logs, and backfill output.
- Produce a triage note identifying whether the issue stems from server persistence, Elm rendering, or backfill/fallback logic.

**Non-Goals:**
- Implementing fixes or backfill writes. Those are follow-up changes.

## Decisions

- Read-only verification: Use server and UI locally without running backfill updates that write to DB. If re-running backfill, run with SKIP_FEED_CACHE_INIT=1 and inspect output only.
- Data collection locations: `~/.cache/quickheadlines/feed_cache.db` for feed rows; `/api/timeline` for API JSON; browser devtools for DOM capture; server stdout/stderr for logs.
- Representative feeds: start with TechCrunch and Hackaday since they're reported. Expand to other problematic feeds if necessary.

Alternatives considered:
- Running an automated end-to-end test: rejected for scope — manual reproduction is faster and suffices for triage.

## Risks / Trade-offs

- [Risk] Developer may accidentally run backfill with writes. → Mitigation: clearly document commands and recommend setting environment variable `SKIP_FEED_CACHE_INIT=1` and ensuring backfill writes are disabled.
- [Risk] Local environment differences cause false negatives. → Mitigation: capture logs and DB rows to allow re-analysis and consider running backfill on a copied DB file.

## Migration Plan

- N/A — this is read-only verification.

## Open Questions

- Do TechCrunch and Hackaday currently have `header_theme_colors` set in the DB? If yes, are those colors failing WCAG when rendered in the Elm UI?
- Does the backfill output show failures for Google s2 fallback (301) for those feeds? If so, should we follow redirects in the fallback implementation?

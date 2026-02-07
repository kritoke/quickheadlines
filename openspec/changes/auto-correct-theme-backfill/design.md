## Context

This project recently added server-side color extraction and auto-correction logic to ensure feed header text is readable (WCAG 4.5:1). A backfill tool was partially implemented to iterate feeds and upgrade `header_theme_colors.source` from `auto` to `auto-corrected` when safe, or to write corrected theme JSON where needed. The codebase spans Crystal backend code (src/*.cr), a backfill script (scripts/backfill_auto_correct_header_texts.cr), favicon storage, and Elm UI code.

Constraints: must run via `nix develop . --command` (Crystal environment), avoid DB schema changes, and preserve user overrides. Backfill must be idempotent and safe to run multiple times.

## Goals / Non-Goals

Goals:
- Ensure header theme JSON stored server-side is accessible, deterministic, and passes contrast checks.
- Provide a robust backfill to upgrade or correct existing rows where possible, minimizing false positives and not overwriting explicit user overrides.
- Improve favicon fetching to handle common edge cases (redirects, .ico, .svg, Google s2 redirects).
- Ensure Elm UI consumes server-provided themes safely and falls back when necessary.

Non-Goals:
- Change DB schema or introduce new persistent audit columns in this change (can be a follow-up).
- Forcefully overwrite user-provided header_text_color/header_color when user explicitly set them.

## Decisions

- Contrast target: WCAG 4.5:1 for normal text. This is a hard requirement used to accept/upgrade themes.
- Theme correction strategy: prefer to preserve existing theme JSON when it already meets contrast bounds. Only write corrected JSON when necessary. When promoting `auto` -> `auto-corrected`, only do so if both light and dark roles already meet contrast.
- Extraction sources order:
  1. Local saved favicon blob (preferred)
  2. Site homepage parsing for <link rel="icon"> / <link rel="shortcut icon"> / manifest.json icons
  3. Google s2 favicon endpoint (follow redirects)
  This order balances fidelity with reliability.
- Favicon storage: compute a stable hash based on feed site origin + final resolved favicon URL or blob, truncated to a fixed length. Keep original extension when saving.
- Backfill idempotence: skip feeds already `auto-corrected` and skip rows where no correction required. Log attempted changes for audit.

## Risks / Trade-offs

[Network] Backfill requires network access; redirects and remote host blocks may prevent extraction → Mitigation: run backfill in environment with stable HTTP/S access; add robust retries and timeouts.

[False negatives] Some favicons (.ico or multi-resolution formats) may not yield a representative color → Mitigation: parse multiple sources (manifest, homepage), accept grayscale fallback, and leave rows unchanged if uncertain.

[Visual diffs] Correcting many headers will change UI snapshots → Mitigation: update Playwright snapshots deliberately and include notes in the release.

[Policy] Not overwriting explicit user colors may leave some rows with bad contrast forever → Mitigation: document policy, consider a follow-up opt-in aggressive correction.

## Migration Plan

1. Run Crystal specs and ensure all tests pass locally.
2. Build backfill binary: `nix develop . --command crystal build scripts/backfill_auto_correct_header_texts.cr -o bin/backfill_auto_correct_header_texts`
3. Run backfill in a networked environment and capture logs: `nix develop . --command ./bin/backfill_auto_correct_header_texts | tee /tmp/backfill_run.log`.
4. Inspect logs and API snapshot (`/api/feeds`) for samples; run Playwright visual tests and update snapshots where intentional changes occurred.
5. If changes acceptable, schedule backfill on production cache DB (coordinate downtime/maintenance window if necessary).

## Open Questions

- Should the server ever override explicit user-provided `header_text_color` when it fails contrast? (recommended: no in this change)
- Should we add an audit trace of original values when auto-correcting? (recommended: add in follow-up)
- Are there specific blocked domains that require custom favicon handling (bot protection)? If yes, compile a list to special-case.

## Context

Recent refactors extracted favicon logic into `src/fav.cr` and adjusted `src/feed.cr` and `src/favicon_storage.cr`. Several feeds stopped showing favicons; logs point to `.ico` handling either being rejected by size limits or not being recognized as valid image bytes. The system runs inside a Nix devshell with Crystal 1.18.2; any solution must avoid adding heavy external runtime dependencies for now.

## Goals / Non-Goals

**Goals:**
- Quickly validate whether the regression is caused by the favicon size limit (MAX_SIZE) for ICOs and restore missing favicons for affected feeds.
- Add targeted logging and reproducible scripts to capture exact headers and sample bytes for failing hosts.
- Add unit tests to cover ICO magic detection and size acceptance behavior.

**Non-Goals:**
- Adding heavy image processing dependencies or system-level binaries in this change. ICO→PNG conversion may be proposed later if needed.

## Decisions

- Experiment first by increasing `FaviconStorage::MAX_SIZE` from 100KB to 200KB for ICO content. Rationale: low-risk, fast to test; many ICO files are slightly above 100KB due to multiple embedded sizes.
- Add an integration script `scripts/check_favicons.cr` that fetches known failing hosts and prints: final URL, status code, content-type, size, and first 128 bytes (hex). Rationale: deterministic reproduction and data collection for next steps.
- Add unit tests for `ico_magic?` using a sample ICO fixture and for size rejection behavior.

## Risks / Trade-offs

- Risk: Increasing MAX_SIZE may allow storing unexpectedly large or malicious files. Mitigation: keep a reasonable cap (200KB) and ensure downstream code validates image magic bytes.
- Risk: If the root cause is not size but content-type or bot-detection HTML, increasing MAX_SIZE won't help. Mitigation: the debug script will capture sample bytes and headers to rule this out.

## Context

The UI timeline view places a small "pill" with the feed/site title next to each item. On mobile/very-narrow breakpoints the pill's vertical padding and the surrounding container paddings combine to create a title area that appears too tall and visually cramped against the thin separators above and below. The UI uses Elm Element for layout, with responsive helpers in `Responsive.elm` and typography in `ThemeTypography.elm`. Server-provided header colors and data attributes are used; existing JS should not be removed or contradicted.

## Goals / Non-Goals
**Goals:**
- Reduce vertical padding around the timeline site title pill on mobile and very-narrow breakpoints.
- Apply a tighter line-height for title text on small viewports to reduce natural text box height while preserving legibility.
- Keep theme-aware color behavior (server-provided colors) unchanged.
- Keep desktop/tablet layout unchanged.

**Non-Goals:**
- Reworking desktop typography or global spacing tokens.
- Backend/API changes.

## Decisions

- Implementation location: modify `ui/src/Pages/Timeline.elm` (clusterItem) rather than relying only on CSS. Rationale: Elm controls layout attributes (padding, spacing) and Element attributes are more precise and avoid CSS specificity conflicts with data attributes and JS. Also prevents flash-of-style mismatch when Elm re-renders.

- Mobile conditional logic: use existing `Responsive.isMobile` / `Responsive.isVeryNarrow` helpers to choose tighter padding and add inline style for `line-height` (via `Html.Attributes.style`) only on mobile. Rationale: keep spacing responsive and deterministic.

- Fallback CSS: add a small mobile `@media` rule in `views/index.html` to ensure non-Elm consumers or any race conditions (early render before Elm) still show acceptable spacing. This is defensive and minimal.

## Risks / Trade-offs

- [Visual diff risk] Changing spacing will alter Playwright visual snapshots. Mitigation: Update snapshots intentionally and run tests. Keep the change scoped to mobile to limit broad diffs.
- [Theme/color overlap] Inline style for `line-height` must not conflict with server color attributes. Mitigation: only set `line-height` via `Html.Attributes.style` and not change color attributes.
- [Accessibility] Avoid setting line-height too tight. Mitigation: use a safe line-height like 1.15–1.2 and verify legibility on devices.

## Migration Plan

1. Implement Elm edits with mobile-only conditional padding and line-height.
2. Add CSS fallback in `views/index.html` under existing `@media (max-width: 640px)` block.
3. Rebuild Elm (`nix develop . --command cd ui && elm make src/Main.elm --output=../public/elm.js`) and run the dev server (`nix develop . --command make run`).
4. Verify visually and with Playwright tests. If snapshots fail, update them after human review.

## Open Questions
- None — changes are scoped and non-invasive. If you prefer pure CSS-only approach, we can revert Elm edits and only add CSS rules.

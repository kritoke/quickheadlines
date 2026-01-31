## Context

The proposal establishes that favicons are currently rendered above site names in the timeline view, causing visual misalignment especially when items wrap on narrow viewports. This change focuses on the Elm Land frontend under `src/frontend` and aims to correct layout primitives while adhering to the QuickHeadlines Constitution (Element primitives only).

Dependencies:
- Proposal: `proposal.md`

## Goals / Non-Goals

**Goals:**
- Position favicons inline with site names across viewport sizes.
- Ensure vertical centering with headline text without disrupting existing accessibility semantics.
- Add visual regression tests to prevent regressions.

**Non-Goals:**
- Rewriting the timeline component or changing data shape. No API/backend work.

## Decisions

- Use an inline `Element` row container for the favicon + site name within the timeline item, with explicit alignment rules, rather than floating or absolute positioning.
- Avoid introducing new CSS frameworks; use `mdgriffith/elm-ui` primitives only.
- Provide a small helper function `Timeline.viewIcon : String -> Element msg` that returns a constrained image element sized to 16x16 and vertically centered.

Alternatives considered:
- Absolute positioning with offsets (rejected: fragile across breakpoints and content wrapping).
- Using a flexbox wrapper with baseline alignment (rejected in favor of Element primitives to remain consistent with Elm Land guidelines).

## Risks / Trade-offs

- Risk: Small layout changes could affect existing timeline item spacing; mitigate by adding visual snapshots for narrow/wide widths and manual review.
- Risk: Styling differences across browsers; mitigate by limiting to simple sizing and Element primitives.

## Migration Plan

1. Implement `Timeline.viewIcon` and replace current favicon rendering in `Timeline.item`.
2. Add visual snapshot tests for at least two widths (320px, 1280px).
3. Run Elm Land build and review snapshots. Roll back if regressions appear.

## Open Questions

- Do we need to support larger favicon sizes for high-density displays? Recommend handling via `src/ui/image` helpers if necessary.

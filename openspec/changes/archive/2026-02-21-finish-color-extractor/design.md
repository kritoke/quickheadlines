## Context

The project currently has a partially implemented `src/color_extractor.cr` that attempts to extract header/favicons colors and a frontend that applies server-provided colors when available. However, color extraction is incomplete, the server sometimes returns single colors unsuitable for both light/dark themes, and the frontend contains JS fallbacks that override server colors in edge cases. The system must enforce WCAG contrast for both themes and persist theme-aware colors for consistent rendering.

Constraints: Crystal 1.18.2; all commands must be run inside `nix develop . --command`; DB migrations must be safe and non-destructive; backward compatibility with existing `header_text_color` must be maintained.

## Goals / Non-Goals

Goals:
- Provide deterministic, theme-aware (`light` and `dark`) header text colors for feeds
- Enforce WCAG AA contrast (4.5:1) when choosing or generating text colors
- Persist theme-aware colors in the database (new `feeds.header_theme_colors` column)
- Keep frontend simple: Elm should render server-provided colors; JS fallbacks remain temporary
- Minimal runtime overhead on API responses (store JSON in DB as TEXT)

Non-Goals:
- Perfect color harmonization across all brand assets (beyond readability)
- Full redesign of frontend components; aim for minimal Elm updates

## Decisions

1. Storage format: single JSON TEXT column `feeds.header_theme_colors`
   - Rationale: Quick rollout, single DB change, avoids adding multiple migrations for separate columns. JSON structure: {"bg":"#RRGGBB","text":{"light":"#RRGGBB","dark":"#RRGGBB"},"source":"auto|override"}

2. Contrast algorithm: WCAG contrast ratio with sRGB linearization
   - Rationale: Standard method, widely accepted. Use 4.5:1 threshold for normal text.

3. Color selection strategy:
   - Compute dominant background color from favicon (or site header) using existing extraction logic.
   - For light-theme text (dark text), choose black `#000000` if contrast >= 4.5:1 vs bg; otherwise compute a darker color by blending toward black until contrast passes or fallback to `#111111`.
   - For dark-theme text (light text), choose white `#FFFFFF` if contrast >= 4.5:1; otherwise blend toward white until contrast passes or fallback to `#EEEEEE`.

4. Manual overrides handling:
   - If user-specified `header_text_color` exists, validate it for both themes; if it fails for either theme, compute a corrected theme-specific color and store alongside override in `header_theme_colors` with `source` set to `override+auto-corrected`.

5. API shape:
   - Controllers will return `header_theme_colors` as a parsed JSON object when present, and fall back to `header_text_color` for clients that don't handle the new field.

## Risks / Trade-offs

[Risk] Server-side extraction may produce suboptimal contrast for brand-colored headers → Mitigation: prefer correctness (readability) over strictly keeping brand color; store original color in `source` for traceability and possible UI to honor brand with adjusted outline.

[Risk] Database migration may increase row size slightly due to JSON column → Mitigation: column is TEXT, most entries are small; monitor DB size and consider separate columns if needed.

[Risk] Playwright tests may fail due to visual diffs after changing colors → Mitigation: update snapshots after verifying new colors are acceptable.

## Migration Plan

1. Add migration to create `feeds.header_theme_colors` TEXT column; deploy migration.
2. Release server code that writes `header_theme_colors` on feed refresh (backfill happens on next refresh).
3. Run a background re-extract job to populate `header_theme_colors` for all existing feeds gradually.
4. Once stable and frontend updated, consider migrating `header_theme_colors` into dedicated columns for performance.

Rollback: revert migration by removing column (data loss) only if necessary; prefer to disable new API fields instead.

## Open Questions

- Should we provide an admin endpoint to force re-extraction for a single feed? (Recommended: yes)
- Should we backfill all feeds in one big job or an incremental background worker? (Recommended: incremental)

## Context

QuickHeadlines' header and day headers currently use inconsistent styling. The header brand label uses small subtitle typography with basic bold styling, and day headers rely on inline HTML style strings that are hard to maintain. There is no centralized typography hierarchy or theme-aware color tokens for these components. The UI lacks the calm, refined Apple-inspired aesthetic that would improve readability and user experience.

## Goals / Non-Goals

**Goals:**
- Redesign the site header with larger hero typography, subtle backdrop, and consistent theming for light/dark modes.
- Redesign day headers in the timeline with pill-styled elements, muted backgrounds, and a small orange accent.
- Centralize typography helpers (`hero`, `dayHeader`) and theme tokens for maintainability.
- Integrate Inter Variable font with safe system fallbacks via self-hosted WOFF2.
- Ensure accessibility (WCAG AA contrast) and mobile usability (>=44px touch targets).
- Keep all visual styling Elm-driven; use CSS only for the minimal `@font-face`.

**Non-Goals:**
- No functional changes to navigation, routing, or data flow.
- No changes to the feed rendering or timeline logic.
- No sticky day headers (kept non-sticky per user choice).
- No redesign of other UI components beyond header and day headers.

## Decisions

1. **Typography Helpers**
   - Add `hero` and `dayHeader` helpers to `ThemeTypography.elm`.
   - `hero`: 36px desktop / 28px tablet / 20px mobile, semi-bold, 0.6 letter spacing.
   - `dayHeader`: 18px desktop / 16px tablet / 14px mobile, semi-bold.
   - Rationale: Centralized sizing ensures consistency and simplifies responsive adjustments.

2. **Theme Tokens**
   - Add `headerSurface : Theme -> Color` for subtle header backdrop (light: white; dark: rgb(24,24,24)).
   - Add `dayHeaderBg : Theme -> Color` for pill backgrounds (light: rgb(245,247,249); dark: rgb(30,40,54)).
   - Use existing `textColor` and `lumeOrange` tokens where appropriate.
   - Rationale: Theme-driven colors ensure dark/light mode consistency without hardcoded values.

3. **Header Implementation**
   - Replace `brandLabel` in `Application.elm` with an Elm element using `Ty.hero`, `Font.semiBold`, `Font.letterSpacing 0.6`, and `Font.family [ Font.name "Inter var", Font.system ]`.
   - Use `Background.color (headerSurface theme)` and optional `htmlAttribute (HA.style "backdrop-filter" "blur(6px)")` for subtle effect.
   - Add hairline border using `Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }` with a translucent color.
   - Rationale: Elm UI attributes keep styling maintainable and theme-aware.

4. **Day Header Implementation**
   - Replace `dayHeader` function in `Timeline.elm` with a pill-styled row:
     - Small orange accent dot using `el [ width (px 8), height (px 8), Background.color Theme.lumeOrange, Border.rounded 999 ] Element.none`.
     - Pill container using `el [ Background.color (dayHeaderBg theme), Border.rounded 999, paddingXY 8 12 ]`.
     - Date text using `el [ Ty.dayHeader, Font.semiBold, Font.color (textColor theme) ] (text headerTextDisplay)`.
   - Rationale: Clean Elm-driven styling with consistent radius and spacing.

5. **Font Integration**
   - Place `Inter-Variable.woff2` in `public/fonts/`.
   - Add minimal `@font-face` in `views/index.html`:
     ```css
     @font-face {
       font-family: "Inter var";
       src: url("/fonts/Inter-Variable.woff2") format("woff2");
       font-weight: 100 900;
       font-style: normal;
       font-display: swap;
     }
     ```
   - Elm uses `Font.family [ Font.name "Inter var", Font.system ]`.
   - Rationale: Self-hosted WOFF2 ensures reliability and performance; fallback to system fonts.

6. **Motion**
   - Add `htmlAttribute (HA.style "transition" "transform .20s ease-out, opacity .20s ease-out")` to day headers.
   - Rationale: Subtle entry animation without complex CSS.

## Risks / Trade-offs

- **Contrast risk**: Light pill background on light mode may have insufficient contrast. Mitigation: Verify with Lighthouse contrast audit and adjust `dayHeaderBg` token if needed.
- **Font rendering**: Inter may render differently across OS/Browser. Mitigation: System fallback stack (`-apple-system`, etc.) ensures legibility.
- **Mobile sizing**: Hero text at 36px may be too large on narrow screens. Mitigation: Responsive sizes use 20px on mobile.
- **CSS override temptation**: Developers may be tempted to add CSS for styling. Mitigation: All styling in Elm attributes; only `@font-face` in CSS.

## Open Questions

- None. All decisions are resolved per the approved plan.

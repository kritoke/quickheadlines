## Why

The current header and day headers in QuickHeadlines lack visual hierarchy and use inline styles that make the UI feel cluttered. The header text is too small, day headers lack visual distinction, and styling is scattered across Elm and CSS. A "Quiet Refined" redesign will bring the app in line with Apple-inspired design principles: larger, more legible typography, subtle surfaces, and consistent theming that works seamlessly in both light and dark modes.

## What Changes

- **Header redesign**: Larger hero title (36px desktop / 28px tablet / 20px mobile), semi-bold weight, increased letter spacing, and a subtle translucent backdrop with hairline border. Brand label will use the new `Ty.hero` typography helper.
- **Day header redesign**: Replace inline-style day headers with Elm-driven pill-styled headers featuring muted backgrounds, rounded corners, and a small orange accent dot. New `Ty.dayHeader` typography helper for consistent sizing.
- **Typography centralization**: Add `hero` and `dayHeader` helpers to `ThemeTypography.elm` and new color tokens (`headerSurface`, `dayHeaderBg`) to `Theme.elm` for consistent theming across modes.
- **Font integration**: Self-host Inter Variable font with safe system fallbacks. Minimal `@font-face` added to `views/index.html`; all other styling remains Elm-driven.
- **Motion**: Subtle entry fade + translate for day headers using Elm transition attributes.
- **Accessibility**: Ensure WCAG AA contrast for all text, maintain >=44px touch targets on mobile, and verify keyboard focus visibility.

## Capabilities

### New Capabilities
- `ui-header-styles`: Centralized typography and color tokens for the site header.
- `ui-day-header-styles`: Centralized typography and color tokens for timeline day headers.
- `ui-typography-helpers`: New `hero` and `dayHeader` typography helpers.

### Modified Capabilities
- None. This change only refines UI presentation without altering functional requirements.

## Impact

- **Files modified**: `ui/src/Application.elm`, `ui/src/Pages/Timeline.elm`, `ui/src/Theme.elm`, `ui/src/ThemeTypography.elm`, `views/index.html`
- **Files added**: `public/fonts/Inter-Variable.woff2`
- **Dependencies**: None new; uses existing Elm UI patterns and self-hosted font.
- **Breaking changes**: None.

# design-system-cleanup Specification

## Purpose
Defines the structural improvements to the frontend design system: single source of truth for theme definitions, systematic z-index scale, shared breakpoint utility, dead code removal, and correct spacing token aliases.

## Requirements

## ADDED Requirements

### Requirement: Single source of truth for theme color definitions
Theme color definitions SHALL exist in exactly one file (`theme.svelte.ts`). The `app.html` FOUC inline script SHALL contain a minimal self-contained copy with a synchronization comment. The `themeInit.ts` file SHALL be removed.

#### Scenario: Theme colors defined once in TypeScript
- **WHEN** a developer needs to modify a theme's colors
- **THEN** they only need to edit `frontend/src/lib/stores/theme.svelte.ts`
- **AND** `frontend/src/lib/utils/themeInit.ts` does not exist

#### Scenario: FOUC script remains self-contained
- **WHEN** `app.html` inline script runs before Svelte hydration
- **THEN** it contains a minimal color map with a comment: `// SYNC: keep in sync with theme.svelte.ts`
- **AND** both sources produce identical CSS variable output for the same theme

### Requirement: Dark theme detection covers all dark themes
The system SHALL provide an `isDarkTheme(theme)` helper that returns `true` for all dark-background themes: `dark`, `retro`, `matrix`, `ocean`, `sunset`, `hotdog`, `dracula`, `cyberpunk`, `forest`.

#### Scenario: All custom dark themes detected as dark
- **WHEN** `isDarkTheme('matrix')` is called
- **THEN** it returns `true`
- **AND** same for `retro`, `ocean`, `sunset`, `hotdog`, `dracula`, `cyberpunk`, `forest`

#### Scenario: Light theme not detected as dark
- **WHEN** `isDarkTheme('light')` is called
- **THEN** it returns `false`

#### Scenario: FeedBox uses correct dark detection
- **WHEN** `FeedBox.svelte` renders with `matrix` theme active
- **THEN** `getHeaderStyle()` uses `feed.header_theme_colors.dark` values (not `.light`)

#### Scenario: TimelineView uses correct dark detection
- **WHEN** `TimelineView.svelte` renders with `dracula` theme active
- **THEN** `getHeaderStyle()` uses dark-mode header colors

### Requirement: Sunset classified as dark theme in FOUC script
The `app.html` inline script's `darkThemes` array SHALL include `sunset`.

#### Scenario: Sunset gets dark class on initial load
- **WHEN** page loads with `sunset` theme saved in localStorage
- **THEN** `<html>` element has `.dark` class applied before first paint
- **AND** no flash of light-mode styling occurs

### Requirement: Z-index scale constant
The design tokens file SHALL export a `zIndex` constant with named levels: `base(0)`, `header(30)`, `loadingBar(20)`, `dropdown(40)`, `dialog(50)`, `sheet(100)`, `toast(100)`, `scrollToTop(200)`, `effects(300)`.

#### Scenario: No ad-hoc z-index values in components
- **WHEN** components need z-index values
- **THEN** they reference `zIndex.effects`, `zIndex.scrollToTop`, etc. from the tokens
- **AND** no component uses inline `z-index: 999999` or Tailwind `z-[9999999]`

#### Scenario: Cursor trail uses effects z-index
- **WHEN** `Effects.svelte` renders cursor elements
- **THEN** primary cursor uses `zIndex.effects` and trail uses `zIndex.effects - 1`

### Requirement: Shared reactive breakpoint utility
The system SHALL provide a `breakpointState` reactive object in `$lib/utils/breakpoint.svelte.ts` with an `isMobile` boolean property, initialized on mount with a resize listener.

#### Scenario: Single resize listener for isMobile
- **WHEN** application mounts
- **THEN** exactly one `resize` event listener is registered for mobile detection
- **AND** `breakpointState.isMobile` is `true` when `window.innerWidth < 768`

#### Scenario: Components consume shared breakpoint state
- **WHEN** `FeedBox`, `TabSelector`, `ScrollToTop`, `LayoutPicker` need mobile detection
- **THEN** they import and read `breakpointState.isMobile`
- **AND** no component has its own `window.innerWidth < 768` check

### Requirement: Spacing tokens define default and spacious aliases
The `spacing` export in `tokens.ts` SHALL include `default` (mapped to `'16px'`) and `spacious` (mapped to `'24px'`) aliases.

#### Scenario: Button uses spacing.default without TypeScript error
- **WHEN** `Button.svelte` references `spacing.default`
- **THEN** value resolves to `'16px'` with no TypeScript error

#### Scenario: MobileTabSheet uses spacing.spacious without error
- **WHEN** `MobileTabSheet.svelte` references `spacing.spacious`
- **THEN** value resolves to `'24px'` with no TypeScript error

### Requirement: Dead variant prop removed from Card
The `Card.svelte` component SHALL NOT accept a `variant` prop.

#### Scenario: Card component interface
- **WHEN** `Card.svelte` Props interface is examined
- **THEN** no `variant` property exists
- **AND** only `headerColor`, `headerBgColor`, and standard HTML attributes are accepted

### Requirement: Ghost beam themes removed from active array
The `BEAM_THEMES` array in `theme.ts` SHALL only contain theme IDs that exist as selectable themes.

#### Scenario: BEAM_THEMES contains only real themes
- **WHEN** `BEAM_THEMES` is examined
- **THEN** it contains `['cyberpunk', 'matrix', 'dracula', 'ocean']`
- **AND** does NOT contain `'vaporwave'` or `'retro80s'`

#### Scenario: BEAM_COLORS entries preserved as documentation
- **WHEN** `BEAM_COLORS` object is examined
- **THEN** `vaporwave` and `retro80s` entries MAY still exist (no harm) but SHALL NOT appear in `BEAM_THEMES`

### Requirement: Touch device hover glow uses theme variable
The `.hover-glow` touch device fallback in `app.css` SHALL use `var(--theme-shadow)` instead of hardcoded `rgba(150, 173, 141, 0.3)`.

#### Scenario: Touch device glow adapts to theme
- **WHEN** a touch device user views the site with Matrix theme active
- **THEN** the hover glow uses Matrix theme's shadow color
- **AND** NOT the hardcoded sage-green `rgba(150, 173, 141, 0.3)`
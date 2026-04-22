## Context

The current frontend theme system uses a hybrid approach combining Tailwind dark mode classes, data attributes (`data-theme`), and CSS custom properties. This creates significant maintenance overhead with extensive CSS overrides (particularly for Hot Dog Stand and Sunset themes) that target every possible Tailwind class combination. The architecture requires ~100 lines of repetitive CSS per special theme and makes adding new themes extremely difficult.

Key constraints:
- Must preserve all 13 existing themes with identical visual appearance
- Must maintain Hot Dog Stand theme's Windows 3.1 aesthetic characteristics  
- Must preserve mouse cursor trail effects and border beam visual effects
- Must work within existing Svelte 5 + Tailwind + BakedFileSystem build workflow
- Must maintain compatibility with Nix development environment

## Goals / Non-Goals

**Goals:**
- Eliminate CSS override hell by implementing unified token-driven theming
- Reduce app.css file size by ~60% through removal of repetitive theme overrides
- Enable trivial addition of new themes through configuration rather than CSS duplication
- Improve accessibility with semantic HTML while preserving visual design
- Fix performance anti-patterns in theme switching and component rendering
- Maintain pixel-perfect visual parity across all existing themes

**Non-Goals:**
- Changing the visual appearance of any existing theme
- Removing or modifying existing theme functionality (cursor trails, border beams, etc.)
- Altering the build process or deployment workflow
- Adding new visual features beyond what currently exists

## Decisions

**1. Unified Theme Token System over CSS Overrides**
- **Chosen**: Implement comprehensive theme tokens with CSS custom properties
- **Alternative**: Continue using data-attribute specific CSS overrides
- **Rationale**: Tokens provide single source of truth, eliminate `!important` declarations, and enable programmatic theme generation. CSS overrides are fragile, verbose, and unmaintainable.

**2. Component-Level Theming over Global CSS**
- **Chosen**: Pass theme tokens as props to components instead of global CSS inheritance  
- **Alternative**: Rely on CSS variable inheritance throughout component tree
- **Rationale**: Explicit prop passing provides better type safety, enables easier testing, and eliminates dependency on CSS specificity. Global inheritance can be unpredictable with complex component hierarchies.

**3. Preserve Existing Mouse Effects Implementation**
- **Chosen**: Keep Effects.svelte unchanged since it already works correctly with theme tokens
- **Alternative**: Rewrite cursor trail system to use different approach
- **Rationale**: Current implementation is performant, handles mobile/touch events properly, and already sources colors from theme configuration. No need to fix what isn't broken.

**4. Semantic HTML with Visual Theme Preservation**
- **Chosen**: Convert timeline items to `<article>` elements while maintaining identical styling
- **Alternative**: Keep using `<div>` elements to avoid any visual changes
- **Rationale**: Accessibility improvements are critical and can be achieved without visual impact. Proper semantic elements improve screen reader experience without affecting appearance.

**5. Dynamic CSS Variable Generation**
- **Chosen**: Generate all CSS variables programmatically from theme tokens
- **Alternative**: Manually maintain CSS variable definitions alongside TypeScript tokens  
- **Rationale**: Single source of truth prevents drift between JS tokens and CSS variables. Programmatic generation ensures consistency and reduces maintenance burden.

## Risks / Trade-offs

**[Risk] Visual regression in existing themes** → Mitigation: Implement comprehensive visual regression testing with Playwright snapshots for all 13 themes before and after changes

**[Risk] Performance impact from additional reactivity** → Mitigation: Use Svelte 5's `$derived` and `$derived.by()` for efficient computed values; benchmark theme switching performance

**[Risk] Breaking changes to theme extension API** → Mitigation: Document clear guidelines for theme creation; ensure backward compatibility for theme configuration format

**[Risk] Complexity in scrollbar theming implementation** → Mitigation: Focus on WebKit browsers first (primary target), implement Firefox support as separate enhancement if feasible

**[Trade-off] Increased JavaScript complexity vs CSS simplicity** → Acceptable because maintainability gains outweigh initial learning curve; theme tokens provide better developer experience long-term
## Context

QuickHeadlines is a Svelte 5 + SvelteKit RSS reader with 13 themes including "Hot Dog Stand" and "Vaporwave." The current BorderBeam effect:
- Only works on 6 themes (cyberpunk, matrix, vaporwave, retro80s, dracula, ocean)
- Uses spinning gradient animation that feels "gamer aesthetic" rather than professional
- Duplicated color definitions between theme.ts and FeedBox.svelte

User feedback from roast: Replace with subtle, Svelte-native animations that work consistently across ALL themes.

## Goals / Non-Goals

**Goals:**
- Replace BorderBeam with hover glow that works on all 13 themes
- Add entry stagger animations using Svelte's built-in fly transition
- Add particle burst on click using Svelte springs
- Fix code quality issues (duplicated arrays, any types, triple scroll reset)

**Non-Goals:**
- Change the 13 themes or color scheme
- Remove the "effects" toggle
- Refactor theme token system (previous attempt broke the app)
- Touch scrolling CSS (works correctly)

## Decisions

**1. Hover glow over BorderBeam**
- Alternatives: Keep BorderBeam, fade effect, border pulse
- Selected: Theme-colored `box-shadow` on hover via `--theme-shadow` CSS variable
- Rationale: Subtle, works on all themes, uses existing theme CSS variables

**2. Svelte built-in transitions for entry**
- Alternatives: CSS keyframes, Framer Motion, custom springs
- Selected: Svelte's `fly` from `svelte/transition`
- Rationale: Already imported and used elsewhere in codebase (FeedTabs, Toast), no new dependencies

**3. Particle burst using Svelte springs**
- Alternatives: Canvas particles, CSS animations, external library
- Selected: Svelte springs for physics-based motion
- Rationale: Matches existing Effects.svelte cursor trail (also uses springs), organic feel

**4. Entry stagger delay formula**
- Alternatives: Fixed delay, logarithmic scale, random
- Selected: `delay: i * 50` (50ms per item)
- Rationale: Simple, readable, creates cascade without being too slow

**5. Particle count and size**
- Alternatives: Various counts and sizes tested mentally
- Selected: 6 particles, 4px size, theme accent color
- Rationale: Enough visual feedback without overwhelming, accent color ties to theme

## Risks / Trade-offs

- [Risk] Entry animations on large feeds (500+ items) could cause performance issues → Mitigation: Only animate first ~20 items, or disable stagger when item count exceeds threshold
- [Risk] Particle burst on mobile touch could be annoying → Mitigation: Only trigger on click (mouse), not touch
- [Risk] Hover glow on touch devices triggers on tap → Mitigation: CSS `:hover` is tap-hold on mobile, acceptable tradeoff

## Migration Plan

1. Remove BorderBeam from FeedBox.svelte and TimelineView.svelte (but keep component file)
2. Add hover glow CSS classes where BorderBeam was conditionally rendered
3. Add `in:fly` to list items in both components
4. Expand Effects.svelte with burst logic particle
5. Test on all 13 themes (especially Hot Dog Stand)
6. Verify no regressions on mobile

## Open Questions

- Should particle burst trigger on ALL clicks or only on feed item clicks? (Current: all clicks)
- Should entry animations apply to initial load only, or also on "load more"? (Current: both)

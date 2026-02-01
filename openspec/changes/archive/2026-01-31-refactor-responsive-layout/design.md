## Context

Current responsive layout implementation is scattered across codebase with:
- Hardcoded breakpoint values (480, 768, 1024) in multiple files
- Inconsistent padding strategies between pages (Timeline: horizontal/vertical separate, Home: uniform)
- Different breakpoint tiering (Timeline: 3 tiers, Home: 2 tiers)
- Missing max-width constraints on Home page (only Timeline has it)
- Function signatures using raw Int windowWidth or Bool flags instead of typed abstractions

This leads to maintenance burden, inconsistent user experience, and layout bugs (header cutoff, content squeezing, unreadable text on mobile).

Constitution requires Element-first architecture with no raw CSS or inline styles for layout. Current approach violates this by mixing Elm logic with hardcoded values and potential CSS overrides.

## Goals / Non-Goals

**Goals:**
- Create centralized `Responsive.elm` module with typed breakpoint system
- Unify padding and layout behavior across Timeline and Home pages
- Ensure max-width constraints exist on both pages for large displays
- Make all responsive logic type-safe and maintainable
- Preserve existing window resize subscription (already working)

**Non-Goals:**
- Change the overall page structure or information architecture
- Modify backend APIs or data models
- Introduce new external dependencies beyond core Elm libraries
- Alter the single-column layout approach on mobile

## Decisions

**Four-Tier Breakpoint System**
- Use `VeryNarrow | Mobile | Tablet | Desktop` union type
- Decision rationale: Covers full range from phone (<480px) to ultra-wide monitors (≥1024px)
- Alternatives considered:
  - 3-tier (Mobile/Tablet/Desktop): Rejected - doesn't handle very narrow screens well
  - 2-tier (Mobile/Desktop): Rejected - no tablet optimization

**Responsive Helper Functions**
- Create pure functions: `breakpointFromWidth`, `horizontalPadding`, `verticalPadding`, `uniformPadding`, `containerMaxWidth`
- Decision rationale: Pure functions are testable, type-safe, and reusable
- Alternative considered: Mix in component logic - Rejected - violates DRY principle

**Padding Normalization**
- Timeline: Use `paddingXY hPadding vPadding` (simpler than current `paddingEach`)
- Home: Switch from 96px uniform to tiered values (8/16/32/96 based on breakpoint)
- Decision rationale: Consistent user experience across pages
- Alternative considered: Keep different strategies - Rejected - inconsistent behavior

**Max-Width Constraints**
- Desktop: `maximum 1200` (matches current Timeline)
- Tablet: `maximum 1024` (new, reasonable mid-point)
- Mobile/VeryNarrow: `fill` (full viewport width)
- Decision rationale: Prevents layout overflow, ensures centering on large displays
- Alternative considered: No max-width - Rejected - causes cutoff on wide screens

**Component Signature Migration**
- Pass `Breakpoint` type to functions instead of `Bool`/`Int`
- Decision rationale: Type-safe, self-documenting, Elm compiler catches mismatches
- Alternative considered: Keep current signatures - Rejected - maintenance burden, error-prone

## Risks / Trade-offs

**Breaking Change: Function Signature Updates**
- Risk: Affects all components using responsive logic
- Mitigation: Elm compiler will catch mismatches; handle incrementally

**Layout Regression During Migration**
- Risk: Introducing new bugs while refactoring
- Mitigation: Test each breakpoint after major steps; keep original logic visible during refactor

**Performance Impact**
- Risk: Additional module/function call overhead
- Mitigation: Pure functions are optimized by Elm compiler; impact negligible

**Browser Compatibility**
- Risk: Edge cases with non-integer viewport sizes
- Mitigation: Breakpoint logic uses inclusive/exclusive ranges already tested

## Migration Plan

**Step 1: Create Responsive.elm Module**
- Define `Breakpoint` union type
- Implement helper functions (breakpointFromWidth, padding, max-width)
- Test compilation: `nix develop . --command elm make src/Responsive.elm`

**Step 2: Refactor Timeline.elm**
- Import Responsive module
- Replace local isMobile/isVeryNarrow calculations
- Update padding to use Responsive helpers
- Change `paddingEach` to `paddingXY`
- Update function signatures to take `Breakpoint`
- Test compilation and runtime behavior

**Step 3: Refactor Home_.elm**
- Import Responsive module
- Add max-width constraint via Responsive helpers
- Update columnCount and gapValue calculations
- Change function signatures to take `Breakpoint`
- Test compilation and runtime behavior

**Step 4: Cross-Page Testing**
- Manual test at each breakpoint (<480, 480-767, 768-1023, ≥1024)
- Verify header visibility, content readability, no cutoff
- Test window resize triggers real-time updates

**Step 5: Build Verification**
- Rebuild Elm bundle: `nix develop . --command elm make src/Main.elm --output=../public/elm.js`
- Run existing tests: `nix develop . --command npx playwright test`

**Rollback Strategy**
- Git branch per step (step-1-responsive-module, step-2-timeline-refactor, etc.)
- If issue found, `git reset --hard` to previous stable commit
- Revert by branch: `git checkout main && git branch -D refactor/responsive-layout`

## Open Questions

1. **Tablet padding value**: Should 96px (current) be reduced to 32px for tablet tier (768-1023px) for better consistency?
2. **Timeline vertical padding**: Keep separate value (60px on desktop) or normalize to match horizontal (40px)?
3. **Max-width values**: Confirm Desktop 1200px and Tablet 1024px are appropriate?
4. **Header responsiveness**: Keep fixed 16px padding in shared layout or make responsive?
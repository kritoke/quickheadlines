## Context

The current mobile tab selector in `TabSelector.svelte` (lines 68-92) is a thin strip (~48px) at the bottom of the viewport with just a 1px border (`border-slate-200`). It shows "Viewing: [Tab]" with a chevron and opens a bottom sheet when tapped.

### Current Problems
1. **Visually lost** - Thin strip with subtle border gets lost against content below
2. **No elevation** - No shadow to create separation
3. **Hardcoded colors** - Uses `bg-slate-50`, `border-slate-200` regardless of theme
4. **Weak active state** - Just text styling, no background or indicator
5. **Feels utilitarian** - Missing the polish of modern mobile app navigation

## Goals / Non-Goals

**Goals:**
- Create an iOS-style tab bar that feels intentional and polished
- Use frosted glass effect (backdrop blur) for modern aesthetic
- Improve touch targets to minimum 44px (iOS HIG)
- Make active tab visually prominent with filled background
- Support all custom themes with theme-aware colors
- Maintain the bottom sheet interaction for tab selection

**Non-Goals:**
- Change the underlying navigation logic
- Add icons to tabs (staying with text labels to match desktop)
- Modify desktop tab bar (this is mobile-only)

## Decisions

### 1. Fixed Bottom Tab Bar with Frosted Glass
**Decision**: Use `backdrop-blur-xl` with semi-transparent background to create iOS-style frosted glass effect.

**Rationale**: This matches modern mobile OS conventions and creates clear visual separation from scrollable content below.

### 2. Increased Height to 64px
**Decision**: Increase from ~48px to 64px for better touch targets and visual presence.

**Rationale**: iOS recommends minimum 44px touch targets. 64px allows comfortable padding while maintaining visibility. The current 48px is borderline for comfortable tapping.

### 3. Theme-Aware Colors via CSS Variables
**Decision**: Use theme colors from `themeState` instead of hardcoded slate colors.

**Rationale**: The current implementation breaks in dark mode and custom themes. Using `theme-bg-primary` and similar classes ensures consistency.

### 4. Floating Pill Active State
**Decision**: Active tab gets a filled pill shape background, not just text color change.

**Rationale**: This provides clear visual feedback and matches modern tab bar conventions (like iOS App Store category tabs).

### 5. Soft Shadow
**Decision**: Add `shadow-[0_-4px_20px_rgba(0,0,0,0.1)]` to create elevation.

**Rationale**: Shadow is crucial for depth - the tab bar should feel like it's floating above content, not just a border on the page.

### Alternatives Considered

| Alternative | Why Not Chosen |
|-------------|----------------|
| Floating pill in content area | Less discoverable, competes with feed content |
| Full-width fixed header tabs | Would require re-architecture, current header is already full |
| iOS-style icon+text tab bar | Desktop uses text-only, keeping consistent simpler |
| Simple border increase only | Doesn't solve the "ugly" complaint - needs frosted glass + shadow |

## Risks / Trade-offs

- [Risk] Custom theme compatibility → [Mitigation] Use theme-aware CSS classes from existing design system
- [Risk] Shadow rendering on older browsers → [Mitigation] Progressive enhancement - shadow is nice-to-have, core functionality works without
- [Risk] Height increase could push content too low → [Mitigation] The current layout already has bottom padding; we'll ensure adequate spacing

## Context

**Background:** The current header navigation uses a two-row layout with horizontal scrolling for tabs. On desktop, tabs appear in a separate row below the logo/actions. On mobile, tabs scroll horizontally with swipe-only navigation. This pattern fails when there are many tabs (7+) as users must discover content through scrolling rather than having it presented directly.

**Current State:**
- `AppHeader.svelte`: Two-row header (logo/actions row + tabs row)
- `FeedTabs.svelte`: Pill-style tabs with horizontal scroll container
- Header height: ~100px on desktop, multiple rows on mobile

**Constraints:**
- Must maintain existing tab URL behavior (`?tab=tech`, etc.)
- Must support existing action buttons (search, timeline, effects, theme)
- Must work with existing theme system (dark/light modes)
- No new external dependencies

**Stakeholders:** QuickHeadlines users on mobile and desktop viewports

---

## Goals / Non-Goals

**Goals:**
- Reduce header vertical space from ~100px to ~56px on desktop
- Improve tab discoverability with dropdown for overflow
- Create thumb-friendly mobile experience with bottom sheet
- Maintain all existing functionality (search, timeline toggle, effects, theme picker)

**Non-Goals:**
- Collapse action buttons into a menu (keeping all visible per user request)
- Add new themes or color options
- Modify backend API or data models
- Add animation effects beyond basic transitions

---

## Decisions

### 1. Adaptive Tab Selector over Horizontal Scroll

**Decision:** Use adaptive display: show inline tabs with dropdown for overflow on desktop, dropdown button + bottom sheet on mobile.

**Rationale:**
- Dropdown reveals all options at once (high discoverability)
- Single-row header saves vertical space
- Bottom sheet on mobile provides thumb-friendly large targets
- Consistent pattern across viewports

**Alternatives Considered:**
- *Horizontal scroll with chevron buttons:* Still requires user to scroll, medium discoverability
- *Sidebar navigation:* Would require significant layout restructuring, better suited for complex apps with many sections
- *Pill-style scrollable tabs (current):* Already failing with overflow

### 2. Bottom Sheet for Mobile Tab Selection

**Decision:** Use a slide-up bottom sheet with full-width buttons rather than a dropdown menu or modal dialog.

**Rationale:**
- Bottom sheets are a well-understood mobile pattern
- Full-width buttons are easier to tap than dropdown items
- Backdrop provides clear dismissal affordance
- Slide-up animation feels native on mobile

**Alternatives Considered:**
- *Dropdown menu:* Limited screen space, small tap targets
- *Modal dialog:* Feels heavier, less mobile-native
- *Full-page navigation:* Too disruptive to user flow

### 3. Five Tabs Inline Before Overflow

**Decision:** Show 5 tabs inline on desktop before showing "More" dropdown.

**Rationale:**
- 5 tabs + logo + actions fit comfortably in single row on 1400px max-width
- Provides good default visibility for common use cases
- User preference confirmed: "5 tabs"

**Alternatives Considered:**
- *3-4 tabs:* Too conservative, would force dropdown too often
- *6+ tabs:* Risk of crowding the action buttons

### 4. Delete FeedTabs Rather Than Deprecate

**Decision:** Remove `FeedTabs.svelte` entirely rather than keeping as deprecated.

**Rationale:**
- New `TabSelector` replaces all functionality
- No other components depend on `FeedTabs`
- Reduces code maintenance burden
- User preference confirmed: "Delete FeedTabs"

---

## Risks / Trade-offs

### Risk: Dropdown Positioning Near Edge

**Problem:** "More" dropdown may render off-screen when near right edge of viewport.

**Mitigation:** Use `position: fixed` with calculated `left` value, or use Popper.js-style flipping. For MVP, position relative to button with `left-0` and accept minor edge cases.

### Risk: Bottom Sheet Accessibility

**Problem:** Bottom sheet may not properly trap focus, handle escape key, or announce to screen readers.

**Mitigation:** 
- Add `role="dialog"` and `aria-modal="true"` to sheet
- Implement focus trap within sheet
- Close on Escape key press
- Add `aria-label` to sheet title

### Risk: Visual Regression in Tests

**Problem:** Playwright screenshot tests may fail due to changed header layout.

**Mitigation:** Run tests with `--update-snapshots` after implementation to capture intentional changes.

### Risk: Tab Transition Smoothness

**Problem:** Switching from inline to dropdown on window resize may cause jarring visual changes.

**Mitigation:** Use CSS transitions where possible, accept minor resize jump as acceptable trade-off.

---

## Migration Plan

1. **Create components** (`TabSelector.svelte`, `MobileTabSheet.svelte`)
2. **Update AppHeader** to use new components, remove tabContent
3. **Update +page.svelte** to pass new props
4. **Run build** (`just nix-build`) to verify compilation
5. **Run tests** (`cd frontend && npm run test`)
6. **Update snapshots** if needed (`npx playwright test --update-snapshots`)
7. **Delete FeedTabs.svelte**
8. **Verify visually** on desktop and mobile viewports

---

## Open Questions

1. **Should "More" dropdown remember last selection?** Currently no—dropdown always shows same options. Could enhance later.

2. **Should we animate tab transitions?** Currently using simple CSS. Could add View Transitions API for smoother changes.

3. **How to handle exactly 6 tabs?** With 5 inline + 1 overflow, "More" shows only 1 item. Could consider: show all 6 inline, or keep "More" for consistency. Decision: Keep "More" for consistency when >5.

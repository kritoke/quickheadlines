## Context

The current frontend uses mixed navigation patterns causing scroll and UI issues:

1. **AppHeader.svelte** uses `window.location.href` for view switching, causing full page reloads instead of SPA navigation
2. **Feeds page** uses aggressive manual scroll resets with `setTimeout` + 3 different scroll APIs
3. **Timeline page** has no scroll management on navigation
4. Both pages use `$effect` with complex initialization guards that can race with WebSocket updates

The app runs as a SvelteKit SPA (`ssr: false`, `prerender: true`) but doesn't leverage SvelteKit's navigation lifecycle.

## Goals / Non-Goals

**Goals:**
- Unified navigation using SvelteKit's `goto()` for all internal links
- Scroll position management that saves/restores per route
- Consistent navigation lifecycle hooks across all views
- Simplified page initialization using proper SvelteKit patterns

**Non-Goals:**
- Changes to the backend API or data models
- Adding new features or changing UI appearance
- Modifying the WebSocket communication
- Changes to the theme system

## Decisions

### 1. Navigation Store with Per-Route Scroll Tracking

**Decision:** Create `navigationStore.svelte.ts` that maintains a map of route paths to scroll positions.

**Rationale:** SvelteKit doesn't have built-in scroll restoration for SPAs. We need to explicitly track and restore scroll positions per route.

**Alternative Considered:** Use browser's native `history.scrollRestoration = 'manual'` with manual handling. Rejected because it requires more boilerplate per component.

### 2. Use SvelteKit's `onNavigate` Lifecycle

**Decision:** Use `onNavigate` from `$app/navigation` in the layout to handle navigation lifecycle.

**Rationale:** SvelteKit provides `onNavigate` which fires before and after navigation, ideal for scroll management without manual `setTimeout` hacks.

**Alternative Considered:** Continue using `$effect` and manual scroll resets. Rejected because it causes timing issues and doesn't integrate with SvelteKit's navigation events.

### 3. Fix AppHeader with `goto()`

**Decision:** Replace all `window.location.href` with `goto()` from `$app/navigation`.

**Rationale:** `goto()` performs client-side navigation, preserving SPA state and enabling proper scroll management.

**Alternative Considered:** Use `<a href>` links directly. Rejected because we need programmatic navigation and click handlers.

### 4. Simplify Page Initialization

**Decision:** Remove complex `$effect` guards and rely on SvelteKit's `onMount` or just let the store initialization happen naturally.

**Rationale:** The current `$effect` with initialization guards is fragile. With proper navigation lifecycle, pages will initialize correctly on first load.

## Risks / Trade-offs

- **[Risk]** Scroll restoration might feel "jumpy" on fast navigations
  - **Mitigation:** Use CSS `scroll-behavior: smooth` and consider adding a small fade transition

- **[Risk]** WebSocket updates might conflict with navigation
  - **Mitigation:** The current WebSocket update logic saves scroll position before reloading. With unified navigation, we should disable auto-refresh during navigation or use a debounce

- **[Risk]** Browser back/forward navigation
  - **Mitigation:** SvelteKit handles this, but we need to ensure scroll positions restore correctly with `onNavigate`

## Migration Plan

1. Create `navigationStore.svelte.ts` with scroll tracking
2. Update `AppHeader.svelte` to use `goto()` instead of `window.location.href`
3. Add `onNavigate` handler in `+layout.svelte`
4. Remove aggressive scroll code from feeds page `+page.svelte`
5. Add scroll management to timeline page
6. Build and test navigation between all views

## Open Questions

- Should we preserve scroll position when WebSocket triggers a refresh? Currently saves scroll before reload - should we skip this during active navigation?
- Do we want to animate transitions between routes? Would require additional work.

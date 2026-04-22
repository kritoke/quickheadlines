## 1. Critical Bug Fixes

- [x]1.1 Fix `rotationMatrixender()` typo in `crystal-engine.ts:328` to `this.render()`
- [x]1.2 Fix undefined `t` in `theme.svelte.ts:293` to `currentTheme.dotIndicator`
- [x]1.3 Add missing `TabsResponse` import in `api.ts`

## 2. Memory Leak Fixes

- [x]2.1 Fix ScrollToTop `$effect` to return cleanup synchronously instead of from `.then()`
- [x]2.2 Fix CrystalEngine `destroy()` to remove all event listeners (mousedown, touchstart, window move/up)

## 3. Race Conditions and Duplicate Events

- [x]3.1 Add request generation counter to `timelineStore.loadTimeline` and `feedStore.loadFeeds` to discard stale responses
- [x]3.2 Fix duplicate `handleWebSocketMessage` registration — register once, not in both effect factories
- [x]3.3 Remove duplicate particle spawn — remove `onClick` listener in Effects.svelte, keep only `pointerdown`

## 4. Effect Factory Deduplication

- [x]4.1 Extract `createRefreshEffect(refreshFn, config)` shared factory in `effects.svelte.ts`
- [x]4.2 Refactor `createFeedEffects` and `createTimelineEffects` to use the shared factory

## 5. Lazy Loader Utility

- [x]5.1 Create `createLazyLoader<T>(importFn)` utility in `$lib/utils/lazyComponent.ts`
- [x]5.2 Replace per-component lazy patterns in `+page.svelte` and `timeline/+page.svelte`

## 6. Icon Component

- [x]6.1 Create shared `Icon.svelte` component with `name` prop for comment, discussion, close, chevron, spinner
- [x]6.2 Replace inline SVGs across TimelineView, FeedBox, BitsSearchModal, Toast, ThemePicker, TabSelector

## 7. Shared State Components

- [x]7.1 Extract `LoadingSpinner.svelte` component
- [x]7.2 Extract `EmptyState.svelte` component
- [x]7.3 Extract `ErrorMessage.svelte` component
- [x]7.4 Replace duplicated templates in `+page.svelte` and `timeline/+page.svelte`

## 8. API Layer Cleanup

- [x]8.1 Unify `apiFetch` timeout/no-timeout branches into single code path
- [x]8.2 Refactor `doFetchFeeds` to use `apiFetch` instead of reimplementing timeout logic
- [x]8.3 Fix `formatTimestamp`/`formatDate` to use `ms == null` instead of `!ms`

## 9. Anti-Pattern Fixes

- [x]9.1 Convert CrystalEngine animation from `setInterval` to `requestAnimationFrame`
- [x]9.2 Move module-level `onReconnect` side effect into effect `start()` method
- [x]9.3 Convert `onReconnect` to multi-listener pattern with unsubscribe
- [x]9.4 Add error isolation in WebSocket `listeners.forEach` loop
- [x]9.5 Add mount guards to `$effect` blocks in `+layout.svelte`, `+page.svelte`, `timeline/+page.svelte`

## 10. Type Safety

- [x]10.1 Replace `any` types in `timeline/+page.svelte` lazy component variables
- [x]10.2 Type `handleWebSocketMessage` parameter with `WebSocketMessage`
- [x]10.3 Fix unsafe `as Window`/`as HTMLElement` casts in `scroll.ts` using proper narrowing
- [x]10.4 Fix unsafe `as BeamTheme` casts in `theme.ts` — sync `BEAM_THEMES` with `BEAM_COLORS` keys
- [x]10.5 Fix `CustomScrollbar.svelte` timeout type to `ReturnType<typeof setTimeout> | undefined`

## 11. Naming and Readability

- [x]11.1 Rename single-letter variables: `s` → `story` (TimelineView), `t` → `style` (theme), `c` → `scrollTarget` (ScrollToTop), `q` → `lowerQuery` (stores), `i` → `item` (store maps), `saveScrollY` → `preservedScrollY` (effects)
- [x]11.2 Simplify deep nesting in `feedItem.ts` favicon resolution with early returns
- [x]11.3 Simplify TabSelector keyboard navigation by unifying ArrowRight/ArrowLeft branches
- [x]11.4 Replace triple try-catch dynamic import in `navigation.svelte.ts` with static import
- [x]11.5 Remove redundant theme getter functions in `theme.svelte.ts` — export `themes` directly
- [x]11.6 Fix `CrystalBadge.svelte` to use `isDarkTheme()` instead of `=== 'dark'`

## 12. Build Verification

- [x]12.1 Run `just nix-build` and fix any compilation errors
- [x]12.2 Run frontend tests with `cd frontend && npm run test`

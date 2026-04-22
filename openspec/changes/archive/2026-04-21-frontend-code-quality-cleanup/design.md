## Context

The frontend is a Svelte 5 SPA using `adapter-static`, `$state`/`$effect` runes, and Tailwind CSS. It communicates with a Crystal backend via REST + WebSocket. The codebase has grown organically with significant duplication and several latent bugs.

## Goals / Non-Goals

**Goals:**
- Eliminate all runtime crashes and memory leaks
- Follow Svelte 5 idiomatic patterns for reactivity and lifecycle
- Reduce code duplication by extracting shared utilities and components
- Improve type safety across stores, components, and utilities

**Non-Goals:**
- No visual/UX changes
- No backend changes
- No new features

## Decisions

1. **Request cancellation via generation counter** over AbortController — simpler to integrate into existing `fetch` wrappers without propagating signals through all call sites
2. **Shared `createRefreshEffect` factory** over keeping separate `createFeedEffects`/`createTimelineEffects` — eliminates near-identical 50-line blocks
3. **Generic `createLazyLoader<T>` utility** over per-component lazy patterns — type-safe, reusable
4. **Static imports** over dynamic `import()` where no code-splitting benefit exists (scroll.ts, navigation helpers) — simpler, no try-catch nesting
5. **`requestAnimationFrame`** over `setInterval` for CrystalEngine animation — standard browser pattern, auto-pauses on hidden tabs
6. **Multi-listener `onReconnect`** over single-callback — prevents silent overwrites

## Risks / Trade-offs

- [Changing `$effect` cleanup patterns] → Verify each change doesn't break component lifecycle by testing mount/unmount cycles
- [Extracting shared components] → Ensure no regression in styling or behavior; compare screenshots before/after
- [Renaming variables] → Use IDE-wide rename to avoid partial renames; run full build to catch misses

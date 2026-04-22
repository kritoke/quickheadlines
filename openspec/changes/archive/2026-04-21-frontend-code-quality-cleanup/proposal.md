## Why

The frontend codebase has accumulated critical bugs, memory leaks, race conditions, and significant code duplication that degrade reliability and maintainability. A comprehensive cleanup following Svelte 5 best practices is needed.

## What Changes

- Fix 3 critical runtime bugs (typos, undefined variables, missing imports)
- Fix 2 memory leaks (ScrollToTop effect cleanup, CrystalEngine event listener cleanup)
- Fix race conditions in data fetching (no request cancellation on rapid tab switches)
- Fix duplicate event registration (WebSocket handler registered twice, particle double-spawn)
- Refactor duplicated effect factories into shared factory function
- Extract reusable lazy component loader utility
- Extract shared icon component to eliminate SVG duplication
- Extract shared loading/error/empty state components
- Unify duplicated API fetch logic
- Fix unsafe type casts, `any` types, and missing types
- Improve variable naming (single-letter vars, misleading names)
- Simplify nested conditionals and over-complicated logic

## Capabilities

### New Capabilities
- `frontend-code-quality`: Comprehensive code quality improvements across all frontend files

### Modified Capabilities

## Impact

- All Svelte frontend files under `frontend/src/`
- Crystal engine animation (`crystal-engine.ts`)
- WebSocket connection handling (`websocket/connection.ts`)
- API layer (`api.ts`)
- Store files (feedStore, timelineStore, theme, effects, connection, navigation)
- Component files (ScrollToTop, Effects, FeedBox, TimelineView, TabSelector, Toast, ClusterExpansion, CrystalBadge, CustomScrollbar, BitsSearchModal, ThemePicker, AppHeader, BorderBeam)
- Utility files (scroll.ts, theme.ts, feedItem.ts, navigationService.ts)

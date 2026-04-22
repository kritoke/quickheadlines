## Why

The current Svelte 5 implementation suffers from architectural debt that makes maintenance difficult and introduces potential bugs. Key issues include inconsistent state management mixing global and local state, manual cache implementations with complex eviction logic, oversized components with excessive responsibilities, and theme configuration scattered across multiple data structures. This refactoring will establish a clean, maintainable architecture that follows Svelte 5 best practices and reduces technical debt.

## What Changes

- **State Management**: Extract component-level state into dedicated stores for feeds, timeline, and configuration to eliminate duplication and improve testability
- **Theme System**: Consolidate the 6 separate theme color caches into a single, type-safe theme configuration system
- **Component Architecture**: Split oversized components (+page.svelte at 300+ lines, FeedBox.svelte at 174+ lines) into smaller, focused components following Single Responsibility Principle  
- **Caching Strategy**: Replace manual tab caching with a proper caching library or dedicated cache store with automatic invalidation
- **Code Duplication**: Extract shared logic (search modals, error handling, loading states, config fetching) into reusable utilities and composable functions
- **Type Safety**: Fix type inconsistencies in theme handling and ensure all theme-related code is properly typed

## Capabilities

### New Capabilities
- `svelte-state-management`: Centralized state management patterns for Svelte 5 applications using stores and derived state
- `theme-system`: Unified theme configuration system supporting multiple themes with proper type safety
- `component-architecture`: Guidelines for Svelte 5 component composition and size limits

### Modified Capabilities
- `frontend-architecture`: Update requirements for component size, state management, and code organization

## Impact

- **Affected Code**: All Svelte components in `frontend/src/routes/` and `frontend/src/lib/components/`
- **APIs**: Internal component APIs will change, requiring updates to props and event handlers
- **Dependencies**: May require adding lightweight utility libraries for caching or state management
- **Systems**: Build process and testing will need updates to accommodate new file structure
- **Performance**: Improved through better memoization, reduced re-renders, and optimized data fetching patterns
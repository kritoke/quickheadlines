## Context

QuickHeadlines currently has a Phase 1 bundle size optimization completed, reducing the initial bundle from ~450KB to ~150KB by removing the Inter font and optimizing Tailwind configuration. This Phase 2 aims to further optimize the Svelte 5 frontend through strategic code splitting, lazy loading, and dependency reduction.

The current frontend loads all components upfront, including the TimelineView, SearchModal, and all theme styles, even when they're not immediately needed. The Bits-UI library provides essential maintainability benefits by reducing custom code complexity.

## Goals / Non-Goals

**Goals:**
- Reduce initial JS bundle size by 20-30% (from ~58KB to ~40-45KB)
- Reduce critical CSS from ~15KB to ~10KB
- Improve Time to Interactive by >200ms
- Implement lazy loading for non-critical components (TimelineView, SearchModal)
- Split theme CSS into conditional loads
- Maintain Bits-UI components for maintainability while optimizing through code splitting
- Implement advanced Vite code splitting with manualChunks

**Non-Goals:**
- Backend Crystal changes
- Database schema modifications
- Breaking existing functionality
- Adding new features beyond optimization
- Introducing new external dependencies
- Replacing Bits-UI with custom components

## Decisions

### Lazy Loading Strategy
**Decision**: Use SvelteKit's built-in dynamic imports for TimelineView and SearchModal
**Rationale**: SvelteKit provides excellent code splitting support out of the box. Using `() => import('./component.svelte')` ensures components are only loaded when needed, without requiring additional build configuration.

### Theme CSS Splitting
**Decision**: Extract theme-specific styles into separate CSS files with base styles inlined
**Rationale**: Current app.css contains all theme variants (light, dark, matrix, retro80s, etc.) which bloats the critical CSS. By splitting themes, we can load only the active theme's CSS after initial render, reducing parsing time and memory usage.

### Bits-UI Maintenance
**Decision**: Retain Bits-UI components and optimize through code splitting rather than replacement
**Rationale**: Bits-UI was specifically implemented to reduce maintenance overhead and avoid the custom code complexity that becomes a nightmare to maintain when making changes. Instead of replacing it, we'll optimize its bundle impact through Vite manualChunks configuration.

### Code Splitting Configuration
**Decision**: Implement manualChunks in vite.config.ts for better caching
**Rationale**: Automatic code splitting doesn't always produce optimal chunks. Manual chunking allows us to group vendor dependencies (Svelte core, utils, Bits-UI, Tailwind) separately from application code, enabling better long-term caching since vendor code changes less frequently.

### Alternative Considered
We considered replacing Bits-UI with custom components, but this would reintroduce the maintenance overhead that Bits-UI was designed to solve. The optimal approach is to keep Bits-UI and optimize its delivery through proper code splitting.

## Risks / Trade-offs

**[Risk] Initial timeline page load may be slightly slower** → Mitigation: Preload TimelineView when user hovers over timeline link or implement smart prefetching based on user behavior

**[Risk] Theme switching may have brief visual flicker** → Mitigation: Load theme CSS asynchronously but show loading state, or preload common theme transitions

**[Risk] Manual chunking may break if dependencies change** → Mitigation: Document chunk strategy and include comprehensive testing for bundle integrity

## Migration Plan

1. **Implement lazy loading** for TimelineView and SearchModal
2. **Split theme CSS** into base and theme-specific files
3. **Configure Vite manualChunks** for optimal code splitting (including Bits-UI in vendor chunk)
4. **Test thoroughly** with Lighthouse and manual verification
5. **Deploy and monitor** performance metrics

Rollback strategy: Revert the branch if any performance regression or functionality issues are detected.

## Open Questions

- Should we implement intelligent prefetching for TimelineView based on user scroll position?
- Is there benefit to further splitting the main page components?
- Should we consider using Svelte's built-in `<svelte:component>` for dynamic theme loading?
## Why

This change implements Phase 2 of bundle size optimization for the QuickHeadlines Svelte 5 frontend. Building on Phase 1 optimizations (which achieved a ~58KB bundle), this phase targets further reduction through strategic code splitting, lazy loading, and dependency optimization. The goal is to reduce initial bundle size by 20-30% and improve Time to Interactive (TTI) through progressive loading of non-critical components.

## What Changes

### 1. Lazy Loading for TimelineView Component

**Implementation:**
- Convert `TimelineView.svelte` to use dynamic imports
- Load the component only when user navigates to `/timeline` route
- Use SvelteKit's built-in code splitting with `+page.ts` lazy loading

**Expected Impact:**
- ~8-12KB reduction in initial bundle
- Timeline page loads slightly slower on first visit but improves overall perceived performance

### 2. Split Theme CSS into Conditional Loads

**Implementation:**
- Extract theme-specific CSS into separate files: `theme-base.css`, `theme-light.css`, `theme-dark.css`, `theme-custom.css`
- Load base styles inline (critical CSS)
- Defer loading of theme-specific styles
- Use CSS `@media` queries to reduce redundant selectors in base bundle

**Current State:**
- All themes (light, dark, matrix, retro80s, ocean, sunset, hotdog) loaded in single `app.css`
- ~419 lines of mixed theme styles

**Expected Impact:**
- ~5-8KB reduction in critical CSS
- Faster initial paint as less CSS needs parsing

### 3. Optimize Bits-UI Imports & Replace with Lightweight Custom Components

**Implementation:**
- Audit all `bits-ui` imports in the codebase
- Replace heavy Bits-UI components with lightweight custom Svelte 5 implementations
- Current `bits-ui` version: ^2.16.2 (devDependency)

**Target Replacements:**
- `bits-ui` Button component → Custom `ui/Button.svelte`
- `bits-ui` Card component → Custom `ui/Card.svelte`
- Check for any other Bits-UI usage

**Expected Impact:**
- ~15-20KB reduction (Bits-UI tree-shaking is limited)
- Reduced dependency on external UI library

### 4. Advanced Code Splitting with manualChunks in Vite Config

**Implementation:**
- Add `manualChunks` configuration to `vite.config.ts`
- Split vendor dependencies into separate chunks:
  - `vendor-svelte`: Svelte core runtime
  - `vendor-utils`: Utility libraries (clsx, tailwind-merge)
  - `vendor-tailwind`: Tailwind CSS processing
- Enable dynamic chunk names for better caching

**Current State:**
- Currently using SvelteKit default code splitting
- No custom chunking strategy

**Expected Impact:**
- Better long-term caching (vendor code changes less frequently)
- Parallel chunk loading via HTTP/2

### 5. Conditional SearchModal Loading

**Implementation:**
- Add lazy loading for `SearchModal.svelte`
- Only load when user clicks search icon or presses `/` shortcut
- Use dynamic import: `import('./SearchModal.svelte')`

**Expected Impact:**
- ~3-5KB reduction in initial bundle
- Search functionality still instant when triggered

### 6. Font Subsetting (Future-Proofing)

**Implementation:**
- Add documentation for font subsetting if Inter font is reintroduced
- Create `vite-plugin-fontsubset` configuration example
- Document subsetting to Latin characters only

**Expected Impact:**
- Future-ready configuration
- ~20-30KB savings if custom fonts used

## Capabilities

### New Capabilities
- `lazy-timeline-view`: TimelineView component loads on-demand
- `conditional-theme-css`: Theme styles load conditionally
- `lightweight-ui`: Custom UI components replace Bits-UI
- `optimized-chunking`: Manual Vite code splitting
- `lazy-search-modal`: SearchModal loads on-demand
- `font-subsetting-ready`: Font optimization infrastructure

### Modified Capabilities
- `theme-system`: Enhanced with conditional CSS loading for better performance

## Optimization Strategy

### Bundle Size Targets
| Metric | Current (Phase 1) | Target (Phase 2) | Reduction |
|--------|-------------------|------------------|-----------|
| Initial JS | ~58KB | ~40-45KB | 20-30% |
| Critical CSS | ~15KB | ~10KB | 33% |
| TTI | Baseline | -200ms | Improved |

### Loading Strategy
1. **Critical Path** (inline): Base layout, header, light theme base
2. **Deferred** (async): TimelineView, SearchModal, dark theme, custom themes
3. **On-Demand**: Theme switching, search modal

### Chunk Strategy
```
Initial Load:
├── app.js (~25KB)
├── vendor-svelte.js (~15KB)
└── vendor-utils.js (~5KB)

Lazy Chunks (loaded on demand):
├── timeline.js (~10KB) 
├── search-modal.js (~5KB)
├── theme-dark.css (~3KB)
└── theme-custom.css (~5KB)
```

## Impact

**Affected Code:**
- `frontend/src/routes/timeline/+page.svelte` - Lazy load TimelineView
- `frontend/src/routes/+page.svelte` - Add lazy SearchModal
- `frontend/vite.config.ts` - Add manualChunks configuration
- `frontend/src/app.css` - Split theme styles
- `frontend/src/lib/components/SearchModal.svelte` - Dynamic import wrapper
- `frontend/src/lib/components/ui/Button.svelte` - Replace Bits-UI
- `frontend/src/lib/components/ui/Card.svelte` - Replace Bits-UI
- `frontend/src/lib/components/TimelineView.svelte` - Export for lazy loading

**Dependencies:**
- Vite 7.x (existing)
- SvelteKit 2.x (existing)
- Tailwind CSS 4.x (existing)
- No new dependencies required

**Systems:**
- Svelte 5 frontend only
- No Crystal backend changes
- No database schema changes

**Testing:**
- Verify bundle size with `npm run build` and analyze output
- Measure TTI with Lighthouse/Playwright
- Test lazy loading works correctly
- Verify all themes still render correctly
- Test search modal opens correctly

## Performance Measurement

### Pre-Optimization Baseline
```bash
# Build and analyze
cd frontend && npm run build
# Check .svelte-kit/output/client for chunk sizes
```

### Post-Optimization Verification
- Bundle size reduction: 20-30%
- Lighthouse performance score: >90
- TTI improvement: >200ms reduction
- All existing functionality preserved

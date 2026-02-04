# Design: UI Styling Improvements and Release Cleanup

## Context

### Background
QuickHeadlines has accumulated technical debt and visual inconsistencies:
- Timeline day headers have inconsistent styling between light/dark modes
- Feed cards lack visual polish and have irregular spacing
- Header colors flash on page load due to ColorThief re-extraction
- Debug console.log statements remain in production code
- Clustering functionality needs verification

### Current State
- Day headers use orange highlight but colors are inconsistent
- Feed cards have varying padding and alignment
- Header colors are extracted fresh on every page load
- Multiple console.log statements for debugging remain
- Clustering service implemented but may need tuning

### Constraints
- Must work on both light and dark modes
- No new external dependencies
- Changes should be CSS/Elm-only where possible
- JavaScript color caching should be minimal

## Goals / Non-Goals

### Goals
1. Create consistent, visually appealing day headers for timeline
2. Standardize feed card styling with proper dark mode support
3. Implement header color caching to prevent flashing
4. Remove all debug console statements
5. Verify clustering is working correctly

### Non-Goals
- Complete redesign of the application layout
- Adding new features beyond styling improvements
- Backend architecture changes
- Mobile-specific optimizations (focus on desktop)

## Decisions

### 1. Header Color Caching Strategy

**Decision:** Use localStorage with 7-day expiration

**Rationale:**
- localStorage is already available and requires no new dependencies
- 7 days provides reasonable balance between freshness and stability
- Immediate application of cached colors prevents flash
- Fallback to theme colors if cache unavailable

**Alternative Considered:** IndexedDB
- More storage capacity but significantly more complex
- Overkill for simple color value storage
- Rejected due to complexity

### 2. CSS Organization

**Decision:** Keep all CSS in views/index.html `<style>` block

**Rationale:**
- Simplifies deployment (no external CSS file)
- Prevents loading race conditions
- Easier to maintain single source of truth

### 3. Day Header Styling Approach

**Decision:** Use subtle background with consistent padding and borders

**Rationale:**
- Subtle backgrounds are more professional than bright highlights
- Borders provide clear visual separation
- Works well with both light and dark themes

### 4. Debug Code Removal

**Decision:** Remove all console.log statements and related debug infrastructure

**Rationale:**
- Console spam makes debugging actual issues harder
- Debug panels serve no purpose in production
- Development can re-enable via feature flags if needed

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Cached colors become outdated | 7-day expiration forces re-extraction |
| Dark mode colors uncomfortable | Use muted colors that work in both modes |
| Breaking existing functionality | Test all changes before deployment |
| Clustering verification takes time | Create test script to verify clustering |

## Migration Plan

### Phase 1: Cleanup (No User-Facing Changes)
1. Remove all console.log statements from views/index.html
2. Remove debug panel and related JavaScript
3. Remove commented-out debug code
4. Verify elm.js compiles without --optimize warnings

### Phase 2: Header Color Caching
1. Add localStorage read on page load
2. Apply cached colors immediately
3. Only re-extract if cache expired or missing
4. Store with timestamp for expiration

### Phase 3: Timeline Day Headers
1. Design consistent header styling (background, padding, border)
2. Implement in CSS
3. Test both light and dark modes

### Phase 4: Feed Card Styling
1. Standardize card padding and spacing
2. Fix text color contrast in dark mode
3. Add hover states
4. Verify favicon alignment

## Testing Strategy

### Color Caching
- Verify cached colors apply on page load
- Verify colors re-extract after 7 days
- Verify no flash on refresh

### Styling
- Screenshot comparison for visual regression
- Manual testing in both light and dark modes
- Check all screen sizes

### Clustering Verification
- Run `/api/run-clustering` endpoint
- Check database for cluster assignments
- Verify clusters appear in timeline view

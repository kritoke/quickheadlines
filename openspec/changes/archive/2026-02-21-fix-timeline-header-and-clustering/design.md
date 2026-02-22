## Context

The QuickHeadlines application has two main views: Home and Timeline. The application uses a shared header component in Elm (`Application.elm:283-356`), but users report inconsistent header styling between these views on desktop. Additionally, the story clustering algorithm uses a two-pass approach (LSH + Jaccard similarity) with a threshold of 0.85, which users report is too restrictive - it only groups stories with nearly identical titles, missing opportunities to cluster related stories with similar but not identical headlines.

Current state:
- Header: Shared component `headerView` renders the same structure for both views, but may have CSS/styling differences
- Clustering: Uses `LexisMinhash::Engine` with SIMILARITY_THRESHOLD = 0.85, applying same threshold to all headlines regardless of length (short headlines <5 words get 0.85 from `ClusteringService` line 97)

Constraints:
- Must maintain backward compatibility with existing UI
- Clustering changes should not introduce excessive false positives
- Header changes must work across both light and dark themes
- Mobile responsiveness must be preserved (current breakpoints: VeryNarrow < 640px, Mobile < 768px, Desktop >= 768px)

## Goals / Non-Goals

**Goals:**
- Align header visual appearance (spacing, padding, layout) between Home and Timeline views on desktop breakpoints (>=640px)
- Improve clustering sensitivity to identify more related stories while maintaining quality
- Increase horizontal padding on headers for better visual breathing room

**Non-Goals:**
- Complete redesign of header component (incremental improvements only)
- Clustering algorithm rewrite (adjust parameters only)
- Changes to mobile header behavior (focus on desktop consistency)

## Decisions

### 1. Header Consistency Approach

**Decision**: Standardize header CSS using a shared CSS class applied via Elm, ensuring identical rendering across views.

**Rationale**: 
- The current implementation uses inline styles and Element library attributes, which can produce slightly different output depending on context
- Adding a shared CSS class like `site-header` ensures consistent application of padding, spacing, and layout
- More maintainable than duplicating Elm code

**Alternatives considered**:
- Separate header components for each view: Rejected - increases code duplication
- Using Elm's `Element` attributes only: Rejected - can produce subtle differences due to different container contexts

### 2. Clustering Threshold Adjustment

**Decision**: Lower the similarity threshold from 0.85 to 0.75 for headlines with 5+ words, and introduce a tiered threshold system based on headline length.

**Rationale**:
- Current threshold of 0.85 is extremely high - requires near-identical titles
- Studies show Jaccard similarity thresholds of 0.6-0.8 work well for news clustering
- Shorter headlines (<5 words) should remain at higher threshold (0.85) to avoid false positives on generic terms
- Tiered approach balances precision vs recall for different headline lengths

**Alternative considered**:
- Lower threshold to 0.65 for all headlines: Rejected - would cluster too many generic headlines together

### 3. Header Padding Increase

**Decision**: Increase horizontal padding on desktop headers from current (implicit) spacing to 24px on each side for the main header container.

**Rationale**:
- Users request "more padding on both sides" for better visual breathing room
- 24px is standard practice for desktop headers (based on Material Design guidelines)
- Improves readability and visual hierarchy

**Alternative considered**:
- Keep current padding: Rejected - doesn't address user feedback

## Risks / Trade-offs

### Header Changes
[Risk] CSS class conflicts with existing styles → Mitigation: Use specific class names like `.qh-site-header` with sufficient specificity
[Risk] Breaking mobile responsiveness → Mitigation: Apply padding increases only on desktop breakpoints (`@media (min-width: 640px)`)
[Risk] Theme inconsistencies → Mitigation: Test both light and dark modes; ensure CSS variables are used correctly

### Clustering Changes
[Risk] Increased false positives (unrelated stories clustered together) → Mitigation: Monitor clustering quality after deployment; add DEBUG_CLUSTERING flag for testing
[Risk] Performance degradation with more clusters → Mitigation: Current LSH approach already limits candidates; 0.75 threshold still maintains reasonable clustering
[Risk] Database bloat with larger clusters → Mitigation: Monitor cluster sizes; consider max cluster size limit if needed

## Migration Plan

1. **Header Styling**:
   - Add `.qh-site-header` CSS class with standardized padding and spacing
   - Update Elm `headerView` to apply this class via `htmlAttribute`
   - Test on desktop breakpoints (768px, 1024px, 1440px)
   - Verify mobile responsiveness unchanged

2. **Clustering Algorithm**:
   - Modify `src/services/clustering_service.cr:97` to use tiered thresholds:
     - <5 words: 0.85 (unchanged)
     - 5-7 words: 0.80
     - 8+ words: 0.75
   - Run clustering on existing data with `DEBUG_CLUSTERING=1` to validate
   - Monitor cluster quality metrics (size distribution, false positive rate)

3. **Rollback Strategy**:
   - Header: Revert CSS changes in `assets/css/input.css`
   - Clustering: Restore previous threshold constants in both `clustering_service.cr` and `lexis-minhash.cr`

## Open Questions

- Should clustering re-run automatically after threshold change, or require manual trigger via `/api/run-clustering`?
- What metrics should be used to evaluate clustering quality (precision/recall, user feedback)?
- Should header padding be configurable via CSS variable for future tuning?

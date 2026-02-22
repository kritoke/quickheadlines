## 1. Header CSS Implementation

- [x] 1.1 Add `.qh-site-header` CSS class to `assets/css/input.css` with 24px horizontal padding on desktop (>=640px breakpoint)
- [x] 1.2 Ensure `.qh-site-header` class respects existing theme variables (light/dark mode colors)
- [x] 1.3 Verify `.qh-site-header` styles only apply on desktop via media query and do not affect mobile breakpoints

## 2. Header Elm Component Updates

- [x] 2.1 Update `ui/src/Application.elm` `headerView` function to apply `.qh-site-header` class via `htmlAttribute`
- [ ] 2.2 Verify header class is applied consistently on both Home and Timeline views
- [ ] 2.3 Test header rendering on both views to confirm identical visual appearance

## 3. Clustering Algorithm - Threshold Logic

- [x] 3.1 Modify `src/services/clustering_service.cr:97` to implement tiered threshold calculation based on word count
- [x] 3.2 Implement threshold logic: <5 words = 0.85, 5-7 words = 0.80, 8+ words = 0.75
- [x] 3.3 Verify word count calculation uses non-stop-word filtering (existing logic in `ClusteringUtilities.word_count`)

## 4. Clustering Algorithm - LSH Configuration

- [x] 4.1 Review `lib/lexis-minhash/src/lexis-minhash.cr` SIMILARITY_THRESHOLD constant (currently 0.85)
- [x] 4.2 Update LexisMinhash documentation to reflect that tiered thresholds are applied in `ClusteringService` layer
- [x] 4.3 Ensure LSH candidate generation remains unchanged (only Jaccard verification thresholds change)

## 5. Testing - Header Styling

- [ ] 5.1 Manually test Home view header on desktop breakpoints (640px, 768px, 1024px, 1440px)
- [ ] 5.2 Manually test Timeline view header on desktop breakpoints (640px, 768px, 1024px, 1440px)
- [ ] 5.3 Compare Home and Timeline headers visually to confirm identical styling
- [ ] 5.4 Verify `.qh-site-header` class presence using browser dev tools on both views
- [ ] 5.5 Test light/dark theme switching on both Home and Timeline views
- [ ] 5.6 Test responsive behavior at breakpoint boundaries (639px vs 640px) to confirm mobile unchanged

## 6. Testing - Clustering Algorithm

- [ ] 6.1 Run clustering with `DEBUG_CLUSTERING=1` flag to observe threshold decisions
- [ ] 6.2 Verify short headlines (<5 words) use 0.85 threshold
- [ ] 6.3 Verify medium headlines (5-7 words) use 0.80 threshold
- [ ] 6.4 Verify long headlines (8+ words) use 0.75 threshold
- [ ] 6.5 Monitor cluster size distribution to detect excessive false positives
- [ ] 6.6 Manually review sample clusters to validate quality improvement over previous 0.85 uniform threshold

## 7. Manual Clustering Trigger

- [ ] 7.1 Trigger manual clustering via `/api/run-clustering` endpoint to reprocess existing stories with new thresholds
- [ ] 7.2 Monitor clustering completion and any error output
- [ ] 7.3 Verify new cluster assignments are saved to database correctly

## 8. Documentation and Code Quality

- [x] 8.1 Add inline comments in `clustering_service.cr` explaining tiered threshold logic
- [x] 8.2 Update CSS comments in `input.css` to document `.qh-site-header` class purpose
- [x] 8.3 Run `nix develop . --command crystal spec` to ensure no Crystal test regressions
- [x] 8.4 Run `nix develop . --command npx playwright test` to ensure no frontend test regressions (3 pre-existing failures, not caused by this change)

## 9. Timeline Alignment

- [x] 9.1 Fix Timeline content alignment with logo by setting `horizontalPadding` to 0px on desktop
- [x] 9.2 Add 24px top padding above Timeline title
- [x] 9.3 Crystal tests pass after changes

## 10. Clustering Stop Word Optimization

- [x] 10.1 Reduce stop words in `ClusteringUtilities` to preserve more headline content
- [x] 10.2 Sync stop word list with `LexisMinhash` library
- [x] 10.3 Crystal tests pass after stop word reduction

## 11. Clustering Database Refresh

- [x] 11.1 Clear all existing cluster assignments (set cluster_id to NULL)
- [x] 11.2 Trigger manual clustering via `/api/run-clustering` endpoint
- [x] 11.3 Verify new clustering completed (500 items processed with new algorithm)

## 12. Clustering Stop Words for Possessive Pronouns

- [x] 12.1 Add "his", "its", "they", "them" back to STOP_WORDS in both ClusteringUtilities and LexisMinhash
- [x] 12.2 Remove extra position/preposition words from LexisMinhash to stop bloat
- [x] 12.3 Crystal tests pass after stop word sync

## 13. Hybrid Clustering (Jaccard + Word Similarity)

- [x] 13.1 Implement `hybrid_similarity` combining Jaccard with word-level fallback
- [x] 13.2 When Jaccard < 0.20, use word similarity (fuzzy matching)
- [x] 13.3 Word similarity uses F1 score (harmonic mean of recall/precision)
- [x] 13.4 Threshold for long headlines: 0.25
- [x] 13.5 Crystal tests pass (73/73)
- [x] 13.6 Re-clustering triggered via `/api/run-clustering`

## Why
The current story clustering algorithm (MinHash/LSH) in version 0.5.0 is reported to be worse than the previous implementation in version 0.4.0. Users are seeing poor grouping results, likely due to the migration to the `lexis-minhash` shard which changed the shingling and similarity logic. A "hybrid" approach was mentioned as a potential fix, combining the speed of MinHash/LSH with the precision of a more direct similarity check.

## What Changes
- **Hybrid Similarity Logic**: Update `ClusteringService` to use a two-pass approach:
  1. Fast candidate lookup using LSH (current).
  2. Precision verification using Jaccard similarity or Levenshtein distance on the actual titles of candidates.
- **Improved Shingling**: Restore/improve the shingling logic to handle stop-words and short headlines better, as seen in the legacy `src/minhash.cr`.
- **Threshold Tuning**: Re-calibrate similarity thresholds specifically for news headlines.

## Capabilities

### New Capabilities
- `hybrid-clustering`: Implements the two-stage (LSH + exact verification) clustering algorithm to ensure high-precision story grouping.

### Modified Capabilities
- `clustering-status-ui`: (No requirement change, but verification of correct clustering results).

## Impact
- `src/services/clustering_service.cr`: Main logic for clustering.
- `src/fetcher.cr`: Background job triggering.
- `lexis-minhash` usage: May need configuration or custom shingling logic.

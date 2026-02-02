## Context
The current story clustering implementation uses the `lexis-minhash` shard exclusively, which has led to a regression in grouping quality compared to the legacy version 0.4.0 implementation. Users report that stories that should be grouped are not, and vice versa. The goal is to restore the high-quality grouping while maintaining the performance benefits of Locality-Sensitive Hashing (LSH).

## Goals / Non-Goals

**Goals:**
- Implement a two-pass "Hybrid" clustering algorithm: LSH for candidate discovery and direct Jaccard similarity for verification.
- Implement robust headline normalization (stop-words, punctuation).
- Support varying similarity thresholds based on headline length.
- Maintain compatibility with the existing `FeedCache` (SQLite) storage for signatures and bands.

**Non-Goals:**
- Replacing the `lexis-minhash` shard entirely (we will use it for the LSH pass but may implement custom normalization).
- Changing the database schema for clustering.

## Decisions

### 1. Two-Pass Verification
**Decision:** We will use LSH (via `lexis-minhash`) to find candidate similar items from the database. For each candidate found, we will compute the Jaccard similarity of their normalized titles using a custom implementation that matches the 0.4.0 logic.
**Rationale:** LSH is efficient for reducing the search space from thousands of items to a few dozen. Direct Jaccard similarity is computationally cheap for short strings like headlines and provides 100% accuracy relative to the normalization rules.

### 2. Custom Normalization & Stop-words
**Decision:** Re-implement the `remove_stop_words` and `generate_shingles` logic from the legacy `src/minhash.cr`.
**Rationale:** The default normalization in `lexis-minhash` is too generic for news headlines. Stop-words like "says" and "reports" frequently appear in headlines across different stories, creating false positives if not filtered.

### 3. Length-Aware Thresholds
**Decision:** Implement a `SHORT_HEADLINE_THRESHOLD` (0.85) and a `MIN_WORDS_FOR_CLUSTERING` (4 words) limit.
**Rationale:** Short headlines (e.g., "Market Update") have high Jaccard similarity due to low word count, even if they refer to different events. Stricter thresholds for short strings prevent "junk" clusters.

## Risks / Trade-offs

- **[Risk]** Higher CPU usage due to the second-pass Jaccard check.
- **[Mitigation]** LSH typically returns < 50 candidates, making the second pass negligible in terms of performance (microseconds per item).
- **[Risk]** Incompatibility with existing stored signatures if normalization changes.
- **[Mitigation]** Signatures will be re-computed and re-stored upon the first fetch/refresh after the update.

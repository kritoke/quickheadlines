## Context

The codebase (~7,250 lines Crystal, 67 files) has accumulated technical debt through accumulated code quality issues. The changes are purely internal refactorings that improve maintainability without altering any external behavior or API contracts.

## Goals / Non-Goals

**Goals:**
- Eliminate all duplicate code patterns identified in the audit
- Replace magic numbers with named constants
- Replace anonymous tuples with named structs for clarity
- Flatten deeply nested conditionals via early returns and extracted helpers
- Rename unclear variable/method names to improve readability

**Non-Goals:**
- No new features or capabilities
- No API or behavior changes
- No dependency changes
- No database schema changes

## Decisions

### 1. Dead code removal
Remove the duplicate `find_dark_text_for_bg_public` and `find_light_text_for_bg_public` methods which are identical. Keep `find_dark_text_for_bg_public` renamed to `suggest_foreground_for_bg`.

### 2. Structs for tuple returns
Create two new private records in `feed_fetcher.cr`:
- `FetchAbortDecision` with fields `should_abort : Bool`, `reason : String?` and helper `abort?` method
- `FetchErrorResult` with fields `data : FeedData?`, `retries : Int32`

### 3. Row-reading helper extraction in FeedRepository
Extract private methods:
- `read_feed_entity(row)` → maps a DB row to `Entities::Feed`
- `read_item(row)` → maps a DB row to `Item`

### 4. Constants for magic numbers
Add to `constants.cr`:
- `CACHE_FRESHNESS_MINUTES = 5`
- `MAX_BACKOFF_SECONDS = 60`
- `FETCH_BUFFER_ITEMS = 50`
- `BROADCAST_TIMEOUT_MS = 100`

### 5. Rate-limit helper extraction
Extract `with_rate_limit(key, ip, max_requests, window_seconds, &)` in `AdminController` to eliminate duplicated auth+rate-limit boilerplate.

### 6. IP count helper extraction
Extract `decrement_ip_count(ip)` private method in `SocketManager` to eliminate duplicated decrement logic in `unregister_connection` and `cleanup_dead_connections`.

### 7. Text value normalization consolidation
Extract `normalize_text_value(val)` in `ColorExtractor` to handle `Hash`, `String`, and `JSON::Any` inputs, returning `Hash(String, String)`. Use this everywhere instead of duplicating the type branching.

### 8. ColorExtractor flattening
Refactor `auto_correct_theme_json` to use early returns and extracted helpers:
- `parse_color_to_rgb(str)` already exists
- Add `rgb_from_array(arr)` wrapping the `PrismatIQ::RGB.new` call
- Add `needs_wcag_correction?(text_hash, bg_rgb)` returning corrected palette directly

## Risks / Trade-offs

- **Risk**: Refactoring could introduce subtle bugs if edge cases are missed in the duplicated code branches.
  - **Mitigation**: Keep changes minimal and mechanical (extract method refactoring). Run full test suite after each file change.

- **Risk**: Breaking struct vs tuple semantics (Crystal tuples are value types with positional access, structs have named fields).
  - **Mitigation**: Using `record` in Crystal preserves value semantics while adding named field access. No behavioral change.

- **Trade-off**: Some extracted helpers may only be used once after refactoring, making them "unnecessary" abstractions.
  - **Mitigation**: The duplication eliminated was the real problem. The extracted helpers make the original methods significantly more readable.

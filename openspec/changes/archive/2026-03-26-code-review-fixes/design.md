## Context

The QuickHeadlines codebase has several issues discovered during code review:

1. **Favicon path bug** - `FaviconStorage` uses relative path `public/favicons/` which breaks in Docker/FreeBSD when CWD differs from project root. Fresh container instances fail to serve favicons because writes go to a different location than API reads.

2. **Security issues** - `StaticController` exposes `ex.message` in error responses. `CleanupRepository` uses manual SQL escaping instead of parameterized queries. `validate_proxy_url` only checks string patterns, not actual DNS resolution.

3. **Performance issues** - `timeline_item_to_response` in `api.cr` executes 3 queries per item (N+1 pattern). `ColorExtractor.extraction_cache` and `HealthMonitor.feed_health` have unbounded growth.

4. **Code duplication** - SSRF validation logic (30+ lines) duplicated in `feed_fetcher.cr` and `api_controller.cr`.

5. **Magic numbers** - Many hardcoded values not using `Constants` module.

## Goals / Non-Goals

**Goals:**
- Fix favicon path resolution to work correctly in all deployment environments
- Eliminate information disclosure in error responses
- Fix SQL construction to use parameterized queries
- Eliminate N+1 queries in timeline API
- Add bounded cache eviction
- Extract duplicate validation logic to shared utility
- Replace magic numbers with constants

**Non-Goals:**
- No authentication changes (self-hosted single-binary model)
- No API contract changes
- No database schema changes
- No new features

## Decisions

### 1. Favicon Absolute Path

**Decision:** Compute `FAVICON_DIR` as an absolute path at runtime based on `QUICKHEADLINES_CACHE_DIR` or fallback location.

**Rationale:** Relative paths break when CWD differs from project root. Using the cache directory ensures favicons are stored alongside the SQLite database, which already handles paths correctly.

**Implementation:**
```crystal
# In FaviconStorage
FAVICON_DIR = begin
  cache_dir = ENV["QUICKHEADLINES_CACHE_DIR"]? || 
               File.join(HOME.not_nil!, ".cache", "quickheadlines")
  File.join(cache_dir, "favicons")
end
```

**Alternative:** Could pass cache_dir through initialization, but this requires changing the module's API. Environment variable approach is less invasive.

### 2. Error Response Sanitization

**Decision:** Return generic "Internal server error" to clients, log actual error details to STDERR.

**Rationale:** Exception messages can contain file paths, SQL errors, or internal structure that aids attackers. Server logs are appropriate for debugging.

**Implementation:**
```crystal
rescue ex
  STDERR.puts "[ERROR] #{path}: #{ex.message}\n#{ex.backtrace.join("\n")}"
  ATH::Response.new("Internal server error", 500, HTTP::Headers{"Content-Type" => "text/plain"})
```

### 3. Parameterized SQL for IN Clauses

**Decision:** Build placeholder strings dynamically and pass values as args.

**Rationale:** Manual string escaping is error-prone. Parameterized queries are idiomatic Crystal/SQLite.

**Implementation:**
```crystal
# Instead of: url_list = config_urls.map { |url| "'#{url.gsub("'", "''")}'" }.join(",")
# Use:
placeholders = Array.new(config_urls.size, "?").join(",")
result = @db.exec("DELETE FROM feeds WHERE last_fetched < ? AND url NOT IN (#{placeholders})", cutoff, *config_urls)
```

### 4. Batch Cluster Query

**Decision:** Fetch all cluster data for timeline items in a single query using `WHERE id IN (...)`.

**Rationale:** Current N+1 pattern (300 queries for 100 items) is a significant performance issue.

**Implementation:**
```crystal
# Pre-fetch all cluster info for timeline item IDs
cluster_data = {} of Int64 => {cluster_id: Int64?, size: Int32, is_rep: Bool}
if !item_ids.empty?
  # Single query to get cluster_id for all items
  @db.query("SELECT id, cluster_id FROM items WHERE id IN (#{placeholders})", item_ids) do |rows|
    # Build cluster_data hash
  end
  # Then batch get cluster sizes
end
```

### 5. Bounded Cache with LRU Eviction

**Decision:** Add max size and LRU eviction to `ColorExtractor.extraction_cache`.

**Rationale:** Unbounded caches cause memory growth over time. LRU is simple and effective.

**Implementation:**
```crystal
MAX_CACHE_SIZE = 1000

@@extraction_cache = LRU::Cache(String, {bg: String, text: String | Hash(String, String), timestamp: Time}).new(MAX_CACHE_SIZE)
```

**Note:** Check if `lru` shard is available, otherwise implement simple LRU with OrderedHash or similar.

### 6. Shared URL Validation Utility

**Decision:** Create `Utils.validate_proxy_url(url : String) : Bool` and remove duplicate implementations.

**Rationale:** DRY principle - 30+ lines duplicated is a maintainability issue.

**Implementation:**
```crystal
# In src/utils.cr
def self.validate_proxy_url(url : String) : Bool
  # Current implementation from api_controller.cr
end

# In feed_fetcher.cr and api_controller.cr - just call Utils.validate_proxy_url
```

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Cache eviction loses data needed for header colors | LRU only evicts least recently used; colors can be re-extracted on next access |
| Changing favicon path breaks existing cached favicons | Old `public/favicons/` files can be migrated; add migration logic |
| DNS resolution adds latency to proxy checks | Cache resolved IPs briefly; most URLs are checked multiple times |
| Batch query changes timeline sorting | Sorting still happens in SQL; only cluster data is batched |

## Migration Plan

1. **Phase 1 (Low risk):** Code quality fixes
   - Replace magic numbers with constants
   - Extract duplicate validation logic
   - Replace bare rescues with structured logging

2. **Phase 2 (Medium risk):** Security fixes
   - Sanitize error responses
   - Parameterize SQL queries

3. **Phase 3 (Higher risk):** Performance + path fixes
   - Fix favicon paths (may need migration for existing data)
   - Implement batch cluster queries
   - Add bounded cache eviction

Each phase can be deployed independently without breaking the application.

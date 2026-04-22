## Context

The `UrlNormalizer` in `src/utils.cr` currently normalizes URLs by:
- Converting HTTP to HTTPS
- Removing `www.` prefix
- Stripping trailing slashes
- Removing common feed path suffixes (`/feed`, `/rss`, etc.)

However, it does **not** strip query parameters (`?utm_source=...`) or fragments (`#section`). This causes duplicate items when the same article is referenced with different tracking parameters.

## Goals / Non-Goals

**Goals:**
- Strip query parameters (`?key=value...`) from URLs during normalization
- Strip fragments (`#section`) from URLs during normalization
- Prevent duplicate items from UTM-tagged URLs

**Non-Goals:**
- Preserving specific query parameters that affect content (not a concern for RSS items)
- Fragment-based routing in feeds (no feeds use this)

## Decisions

**Decision: Strip query params and fragments in `UrlNormalizer.normalize`**

Current implementation at `src/utils.cr:168`:
```crystal
def self.normalize(url : String) : String
  normalized = url.strip
  # ... existing logic ...
end
```

Proposed change - add after `normalized.rchop('/')`:
```crystal
# Strip query parameters and fragments
if query_idx = normalized.index('?')
  normalized = normalized[0...query_idx]
end
if frag_idx = normalized.index('#')
  normalized = normalized[0...frag_idx]
end
```

**Rationale:** Minimal change to existing code, keeps all normalization in one place.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Some feeds may legitimately use query params for content | Most RSS feeds don't; fragments never used in feeds |
| Existing items with query params won't be re-normalized | Not a problem - they won't be created as new items going forward |

## Context

The clustering algorithm correctly prevents same-feed duplicates by checking `feed_id`. However, feeds with different IDs but the same base domain (e.g., `arstechnica.com` and `arstechnica.com/science`) can still cluster together, creating "duplicate" clusters from the same publisher.

## Goals / Non-Goals

**Goals:**
- Extract base domain from feed URLs
- Skip clustering when items are from feeds with the same base domain
- Preserve existing same-feed check as a fast path

**Non-Goals:**
- Not changing how domains are stored (compute on-the-fly)
- Not adding user configuration for domain groups

## Decisions

1. **Extract domain at cluster time**: Parse feed URL to extract domain using URI module
2. **Compare domains in clustering**: Add check after feed_id comparison
3. **Use simple domain extraction**: `URI.parse(url).host` - handles subdomains naturally

## Risks / Trade-offs

- [Risk] URI parsing adds overhead → **Mitigation**: Only parse when needed (after LSH candidate matching)
- [Risk] Some domains have multiple TLDs (google.com vs google.co.uk) → **Mitigation**: Accept as limitation; they ARE different domains

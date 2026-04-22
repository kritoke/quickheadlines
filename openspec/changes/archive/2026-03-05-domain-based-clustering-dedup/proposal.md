## Why

Articles from the same publisher (e.g., Ars Technica and Ars Technica Space) are being clustered together because they have different feed URLs/IDs. Users see this as "duplicate articles from the same source" in the clustered stories area.

## What Changes

- Extract base domain from feed URLs during clustering
- Skip clustering candidates that share the same base domain
- Handle edge cases (subdomains, www prefix, etc.)

## Capabilities

### New Capabilities
- `domain-based-clustering-dedup`: Prevent clustering of articles from feeds sharing the same base domain

### Modified Capabilities
- None

## Impact

- **Code**: `src/services/clustering_engine.cr` and `src/services/clustering_service.cr`
- **User Experience**: Fewer "duplicate" clusters from same publisher

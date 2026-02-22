# Cluster Expansion

## Summary

Allows users to expand clustered timeline items to view all similar stories from multiple sources.

## Behavior

### Cluster Badge Display
- Items with `cluster_size > 1` display a badge showing "X sources"
- Badge is styled consistently with timeline item design
- Badge is clickable/interactive (not just informational)

### Expansion Interaction
- Clicking the cluster badge or a dedicated expand button reveals the cluster
- Expanded view shows all items in the cluster grouped together
- Representative item (first in cluster) remains visible
- Similar stories displayed below with title, source favicon, timestamp, and link

### Expansion UI
- Inline expansion preferred (pushes content down) - OR - Modal/drawer overlay
- Each similar story shows:
  - Feed favicon (16x16)
  - Story title (clickable link to original)
  - Feed name / source
  - Publication timestamp
- Close button to collapse the expansion

### Timeline Filtering
- Timeline shows only `is_representative: true` items by default
- Reduces visual duplication of similar stories
- Users can still discover all coverage via cluster expansion

## API Contract

### Request
```
GET /api/clusters/:cluster_id/items
```

### Response
```json
{
  "cluster_id": "abc123",
  "items": [
    {
      "id": 1,
      "title": "Story Title",
      "link": "https://...",
      "pub_date": "2024-01-15T10:00:00Z",
      "feed_name": "Feed Name",
      "favicon_url": "/api/feeds/.../favicon"
    }
  ]
}
```

## Styling

- Expanded cluster has subtle background distinction
- Dark mode compatible
- Smooth expand/collapse animation
- Consistent typography with timeline items

## Edge Cases

- Single-item clusters (cluster_size = 1) do not show expansion
- Empty clusters handled gracefully
- Network errors show retry option

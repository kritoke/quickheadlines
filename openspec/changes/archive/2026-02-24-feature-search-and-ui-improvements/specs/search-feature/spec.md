# Search Feature Specification

## Overview

Add real-time search across all feeds and timeline items. Users can quickly find specific articles by searching titles and descriptions.

## Requirements

### Scope
- Search feed titles
- Search item titles
- Search item descriptions

### Behavior
- Real-time filtering as user types (via `$derived`)
- Respects active tab (searches within current tab)
- Case-insensitive matching
- Shows "No results" for empty matches

### UI/UX

#### Mobile
- Search icon (magnifying glass) in header
- Tap to expand to full search input
- Slide-down animation
- Tap outside or X to close

#### Desktop
- Always-visible search input in header
- Position: Right side of header, before action icons
- Width: ~250px fixed

#### Highlighted Text
- Matching text should be bolded in results

## Implementation

### State
```typescript
let searchQuery = $state('');
let searchExpanded = $state(false);
```

### Derived Filter
```typescript
let filteredFeeds = $derived.by(() => {
  if (!searchQuery.trim()) return feeds;
  const q = searchQuery.toLowerCase();
  return feeds.map(feed => ({
    ...feed,
    items: feed.items.filter(item => 
      item.title.toLowerCase().includes(q) ||
      (item.description?.toLowerCase().includes(q))
    )
  })).filter(feed => feed.items.length > 0);
});
```

### UI Components
- Search icon button (SVG magnifying glass)
- Search input field
- Clear button (X) when query exists
- Empty state message

## Acceptance Criteria

1. Search icon visible in header on mobile (collapsed by default)
2. Search input always visible on desktop
3. Typing in search filters results in real-time
4. Search works within active tab
5. Clearing search shows all items
6. Empty state shown when no matches
7. Search works on both main page and timeline page

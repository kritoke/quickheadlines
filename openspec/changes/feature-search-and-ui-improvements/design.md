## Design

### 1. 4th Column Grid

**Current:**
```svelte
class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
```

**Change:**
```svelte
class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4"
```

- `xl` breakpoint activates at ≥1280px (standard Tailwind xl)
- Only affects desktop view, no mobile impact
- Maintains gap and card sizing

### 2. CoolMode Cleanup

**Current:**
```svelte
import { onDestroy } from 'svelte';
// ...
onDestroy(() => {
  cleanup?.();
});
```

**Change:** Remove `onDestroy` import and call. The `$effect` already handles cleanup:
```svelte
$effect(() => {
  if (enabled && ref) {
    cleanup?.();
    cleanup = applyParticleEffect(ref, options);
  } else if (!enabled && cleanup) {
    cleanup();
    cleanup = undefined;
  }
  // Cleanup function returned below handles unmount
  return () => { cleanup?.(); };
});
```

### 3. Search Feature

#### Mobile (Space-Saving)
- Search icon (magnifying glass) in header, next to existing icons
- Tap icon → expands to full search input with slide-down animation
- Clear button (X) to close/reset search
- Keyboard: tap outside or press Escape to close

#### Desktop
- Always-visible search input in header
- Position: Between logo/title and action icons (timeline, cool mode, theme)
- Width: ~250px on desktop, full-width on mobile when expanded

#### Behavior
- **Scope**: Feed titles, item titles, item descriptions
- **Real-time**: Filter as user types via `$derived`
- **Tab-aware**: Respects current tab (filters within active tab)
- **Highlighting**: Bold matching text in results
- **Empty state**: "No results for [query]" message

#### Data Flow
```typescript
// State
let searchQuery = $state('');

// Derived filtered feeds
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

### 4. Optimistic UI

#### Tab Switching
- Keep current feeds visible while fetching new tab
- Show subtle loading spinner in tab area
- Swap content only after fetch completes
- If fetch fails, show error but keep cached content

#### Load More
- Immediately show skeleton/placeholder cards (same count as requested)
- Replace with real content when fetched
- Maintain scroll position

#### Background Refresh
- Subtle "updating" indicator in header (small spinner or dot)
- Non-intrusive: doesn't shift layout
- Auto-hides when complete

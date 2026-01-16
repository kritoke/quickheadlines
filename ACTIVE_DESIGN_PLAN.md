# 🗺️ ACTIVE DESIGN PLAN: Fix Infinite Scroll (quickheadlines-4su)

## Problem Analysis

The infinite scroll on the timeline page hangs when scrolling down - it never loads more items.

**Root Cause**: After implementing the infinite scroll, the JavaScript tries to fetch more items from `/timeline_items` but:
1. The API returns HTML with a `.timeline-container` wrapper (containing the sentinel)
2. The JavaScript expects to find `.timeline-item` elements to append
3. Something in the fetch/append chain is failing silently

## Current State

### Server Side (`/timeline_items` endpoint)
- Returns full `timeline.slang` template including:
  - `.timeline-container` wrapper
  - Timeline items
  - Day headers
  - `#infinite-scroll-sentinel` element

### JavaScript Side
- `loadMoreItems()` fetches from `/timeline_items?limit=30&offset=${currentOffset}`
- Parses response into a temporary div
- Looks for `.timeline-container` in the response
- Filters for `.timeline-item` and `.timeline-day-header` elements
- Appends filtered elements to the existing page container

## Proposed Solution

### Option 1: Return Only Items (Simpler)
Create a new template `timeline_items.slang` that renders ONLY the items without container/sentinel.

**Changes:**
1. Create `src/timeline_items.slang` - renders items and day headers only
2. Modify `handle_firehose` to use new template for `/timeline_items` endpoint
3. Update JavaScript to extract items directly from response (no container lookup)

**Pros:**
- Clean separation of concerns
- Smaller response size
- Simpler JavaScript

**Cons:**
- Requires template duplication (items rendered in two places)

### Option 2: Keep Full Template (Safer)
Keep the current template but fix the JavaScript to handle it correctly.

**Changes:**
1. Keep `timeline.slang` as-is
2. Update JavaScript to correctly parse and extract items

**Pros:**
- No template duplication
- Existing structure preserved

**Cons:**
- Larger response (includes sentinel in every request)
- More complex JavaScript parsing

## Recommended: Option 1 (Return Only Items)

### Implementation Steps

1. **Create `src/timeline_items.slang`**
   - Render only: day headers and timeline items
   - No container wrapper
   - No sentinel element

2. **Modify `src/server.cr` - `handle_firehose`**
   - Change from: `Slang.embed("src/timeline.slang", "context.response")`
   - Change to: `Slang.embed("src/timeline_items.slang", "context.response")`

3. **Update `src/timeline_page.slang` JavaScript**
   - Remove: `const newContainer = temp.querySelector('.timeline-container');`
   - Keep: Get existing page container via `document.querySelector('.timeline-container')`
   - Change: Extract items directly from `temp.children` (not from nested container)

4. **Test Flow**
   - Initial page load: `/timeline` renders full page with sentinel
   - Scroll to bottom: JavaScript fetches `/timeline_items?limit=30&offset=X`
   - API returns: Just items and day headers
   - JavaScript: Appends items to page container, updates offset

## Files to Modify

| File | Change |
|------|--------|
| `src/timeline_items.slang` | Create new template (items only) |
| `src/server.cr` | Update `handle_firehose` to use new template |
| `src/timeline_page.slang` | UpdateloadMoreItems()` JavaScript ` function |

## Verification Steps

1. **API Test**: `curl "http://localhost:3030/timeline_items?limit=5&offset=0"`
   - Should return: Day headers + timeline items
   - Should NOT return: Container wrapper or sentinel element

2. **Browser Test**:
   - Open timeline page
   - Scroll to bottom
   - Watch for loading spinner
   - New items should appear and loading spinner reset
   - Repeat until "end of timeline" message

## Quality Gate

```bash
crystal tool format && ameba && crystal spec spec/minhash_spec.cr
```

All tests must pass, no lint errors.

# 4th Column Grid Specification

## Overview

Add a 4th column to the feed grid for extra-wide desktop screens (≥1280px) for improved content density.

## Current Behavior

- Mobile: 1 column (grid-cols-1)
- Tablet: 2 columns (md:grid-cols-2)  
- Desktop: 3 columns (lg:grid-cols-3)

## Proposed Change

- XL Desktop: 4 columns (xl:grid-cols-4)

## Implementation

Edit `frontend/src/routes/+page.svelte` line ~248:

**Before:**
```svelte
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
```

**After:**
```svelte
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
```

## Breakpoints

| Breakpoint | Min Width | Columns |
|------------|-----------|---------|
| default    | -         | 1       |
| md         | 768px     | 2       |
| lg         | 1024px    | 3       |
| xl         | 1280px    | 4       |

## Considerations

- No mobile impact (xl breakpoint is desktop-only)
- Cards maintain consistent sizing
- Gap remains at 4 (gap-4)
- No JavaScript changes required

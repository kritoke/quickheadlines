# Task: TP-004 — Fix Cluster Expansion Flashes Then Disappears

**Created:** 2026-04-30
**Size:** M

## Review Level: 1 (Plan Review)

**Assessment:** Frontend regression — cluster expansion worked before migrating to Skeleton UI framework. The fix requires understanding both the Svelte 5 reactivity model and how Skeleton's CSS/layout interacts with the expansion panel.
**Score:** 5/8 — Blast radius: 1, Pattern novelty: 1, Security: 0, Reversibility: 1

## Canonical Task Folder

```
taskplane-tasks/TP-004-cluster-expansion-bug/
├── PROMPT.md   ← This file (immutable above --- divider)
├── STATUS.md   ← Worker updates this
├── .reviews/   ← Reviewer output
└── .DONE       ← Created when complete
```

## Mission

Fix the cluster expansion UI bug where clicking a clustered story's "N sources"
button briefly flashes the expanded content, then it immediately disappears.
The feature should show clustered/similar stories below the clicked story item.

## Bug Description

When a user clicks the "N sources" button on a clustered story in the Timeline
view, the cluster expansion panel appears for a split second then vanishes.
The expected behavior is for the expansion to remain open showing all similar
stories, and collapse only when clicked again.

## Root Cause Context

The feature **worked before** the migration to the Skeleton UI framework.
The regression happened when the frontend was refactored from custom CSS to
Skeleton's design system. This suggests one of:

1. **Skeleton's CSS is conflicting with the expansion panel** — Skeleton
   applies global styles that may hide/collapse the expansion after render
2. **Layout reflow from Skeleton's grid system** — the grid recalculation
   after expansion causes a re-render that collapses the state
3. **CSS transition/animation conflict** — Skeleton applies transitions that
   interfere with the expansion animation
4. **Svelte 5 `$state` reactivity issue** — the `expandedClusterId` state is
   being reset by a re-render triggered by Skeleton's layout system

## Key Files

| File | Role |
|------|------|
| `frontend/src/lib/components/TimelineView.svelte` | Main timeline with cluster toggle logic. Contains `toggleCluster()`, `expandedClusterId` state, and the `ClusterExpansion` component |
| `frontend/src/lib/components/ClusterExpansion.svelte` | The expansion panel component. Uses Skeleton surface/border tokens for styling |
| `frontend/src/lib/api.ts` | `fetchClusterItems()` API call — returns cluster items from `/api/clusters/{id}/items` |
| `frontend/src/lib/types.ts` | TypeScript types for `TimelineItemResponse`, `ClusterItemsResponse` |
| `frontend/src/lib/stores/layout.svelte` | Layout state including `timelineColumns` — grid column count |
| `frontend/src/app.html` | HTML shell — check for Skeleton app wrapper |

## Detailed Analysis

### TimelineView.svelte — Cluster Toggle Logic

```svelte
let expandedClusterId = $state<string | null>(null);

async function toggleCluster(item: TimelineItemResponse): Promise<void> {
    if (!item.cluster_id) return;
    if (expandedClusterId === item.cluster_id) {
        expandedClusterId = null;  // collapse
        return;
    }
    expandedClusterId = item.cluster_id;  // expand
    // ... fetch cluster items
}
```

The expansion condition:
```svelte
{#if expandedClusterId === item.cluster_id && item.cluster_id}
    <ClusterExpansion ... />
{/if}
```

**Potential issue:** If the grid layout causes items to re-render (new keys,
position changes), the `expandedClusterId` state survives (it's in the parent),
but the item's `cluster_id` comparison may fail if the item object is
recreated by the parent's data flow.

### Skeleton CSS Interference

Skeleton applies these global styles that could cause flash-then-hide:
- `overflow: hidden` on grid children
- Height constraints on grid items
- Transition animations that collapse height changes
- `display: grid` item sizing that clips expanded content

### Grid Layout Issue

The timeline uses a CSS grid (`grid gap-3 {gridClass}`) with responsive
columns. When a grid item expands (cluster expansion adds content below it),
the grid row height changes. This could trigger:
1. Skeleton's layout observer to recalculate and re-render
2. The grid to reflow items, causing Svelte to recreate the `{#each}` block
3. The `{#each}` key (`${date}-${item.id}`) to match but the item object
   to be a new reference, potentially breaking the state comparison

## How to Reproduce

1. Run the app (`just run` or the built binary)
2. Open the dashboard in a browser
3. Find a story with "N sources" badge (cluster_size > 1)
4. Click the "N sources" button
5. Observe: expansion panel flashes briefly then disappears

## Dependencies

- **None** — This is a frontend-only fix independent of TP-001/002/003.

## Context to Read First

- `frontend/src/lib/components/TimelineView.svelte` — Full component
- `frontend/src/lib/components/ClusterExpansion.svelte` — Expansion panel
- `frontend/src/lib/api.ts` — API functions
- `frontend/src/lib/types.ts` — TypeScript types
- `frontend/src/lib/stores/layout.svelte` — Layout state
- `frontend/svelte.config.js` — Skeleton configuration
- `frontend/tailwind.config.ts` — Tailwind/Skeleton theme config

## Environment

- **Workspace:** `frontend/` directory
- **Framework:** Svelte 5 + Skeleton UI v2
- **Testing:** `cd frontend && npm run test` (Vitest)
- **Build:** `cd frontend && npm run build`
- **Services required:** None for unit tests; full app for manual testing

## File Scope

- `frontend/src/lib/components/TimelineView.svelte` — Likely primary fix
- `frontend/src/lib/components/ClusterExpansion.svelte` — Possibly needs CSS fixes
- Possibly `frontend/src/lib/stores/layout.svelte` — If layout observer causes re-render

## Steps

### Step 0: Preflight

- [ ] Verify this PROMPT.md is readable
- [ ] Verify STATUS.md exists in the same folder
- [ ] Read all files listed in "Context to Read First"
- [ ] Understand Skeleton UI's component lifecycle and CSS system

### Step 1: Diagnose the Flash-and-Disappear

- [ ] Add `console.log` to `toggleCluster()` to verify `expandedClusterId` state changes
- [ ] Check if `expandedClusterId` is being reset after the fetch completes
- [ ] Check if Skeleton's CSS applies `overflow: hidden` or height constraints
  that would clip the expansion
- [ ] Check if the grid `{#each}` block is re-rendering items after expansion
  (check if keys change)
- [ ] Look for any Skeleton layout observer or resize handler that might
  trigger a state reset

### Step 2: Fix the State Issue

- [ ] If `expandedClusterId` is being reset: identify what resets it and prevent it
- [ ] If the grid re-renders items: ensure the `{#each}` key is stable and
  the component doesn't unmount/remount
- [ ] If the issue is CSS overflow: override Skeleton's overflow styles on
  the timeline item when expanded

### Step 3: Fix Any CSS/Layout Conflicts

- [ ] Ensure the expanded cluster panel is visible within the grid layout
- [ ] Check that Skeleton's global styles don't collapse the expansion
- [ ] Verify the expansion works in both single-column and multi-column layouts
- [ ] Test both light and dark themes

### Step 4: Run Tests

- [ ] Run `cd frontend && npm run test` — ensure existing tests pass
- [ ] If there are tests for cluster expansion, verify they pass
- [ ] If no tests exist for this specific behavior, consider adding one

### Step 5: Verify Fix

- [ ] Build the frontend: `cd frontend && npm run build`
- [ ] If possible, run the app and manually verify the fix

## Documentation Requirements

**Must Update:** None
**Check If Affected:** None

## Completion Criteria

- [ ] Cluster expansion stays open after clicking "N sources"
- [ ] Cluster expansion shows all similar stories
- [ ] Clicking "N sources" again collapses the expansion
- [ ] Works in both single-column and multi-column layouts
- [ ] Works in both light and dark themes
- [ ] `cd frontend && npm run test` passes
- [ ] `cd frontend && npm run build` passes

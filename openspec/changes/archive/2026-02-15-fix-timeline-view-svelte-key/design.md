## Context

The TimelineView.svelte component renders grouped timeline items by date. It uses an `{#each}` block to iterate over `groupIndex`, which is a derived array of [date, items] tuples. Svelte 5 requires each blocks to have a unique key for proper DOM diffing.

## Goals / Non-Goals

**Goals:**
- Fix the Svelte 5 "Each block should have a key" error in TimelineView.svelte
- Ensure correct DOM updates when timeline items are added/removed

**Non-Goals:**
- No refactoring of the grouping logic
- No changes to API or data fetching

## Decisions

- Use the date string as the key since it's unique per group: `{#each groupIndex as [date, dateItems] (date)}`

## Risks / Trade-offs

- Minimal risk: adding a key is a standard Svelte best practice
- No breaking changes

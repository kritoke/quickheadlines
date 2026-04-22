## Why

The current timeline view shows a global chronological stream of all items from all feeds, but users often want to see a chronological view limited to just their currently selected feed tab. This creates a gap in functionality - users can either see feeds organized by source (feed box view) or everything chronologically (global timeline), but cannot see just their current tab's content in chronological order.

## What Changes

- Add a new "Timeline" view that shows only items from the currently selected feed tab in chronological order
- Rename the existing timeline view to "Global Timeline" to distinguish it from the new tab-specific timeline
- Update navigation icons to better represent each view:
  - Global Timeline: 🌐 globe icon
  - Feed Box View: 📦 box/package icon  
  - Tab Timeline: ⏱️ clock icon
- Modify the UI layout to place the Global Timeline icon to the left of the view toggle but to the right of search
- Update routing and state management to support the new tab-specific timeline view

## Capabilities

### New Capabilities
- `tab-timeline-view`: Provides chronological viewing of items limited to the currently selected feed tab

### Modified Capabilities
- `global-timeline-view`: Updates the existing timeline to be explicitly named "Global Timeline" and adds globe icon
- `feed-navigation`: Modifies the navigation UI to include three distinct view options with appropriate icons

## Impact

- Frontend Svelte components: navigation.svelte.ts, timelineStore.svelte.ts, feedStore.svelte.ts
- API endpoints: May need new endpoint or parameter for tab-specific timeline data
- CSS/Tailwind styling for new icons and layout changes
- Route handling in SvelteKit frontend
- User interface and user experience flows
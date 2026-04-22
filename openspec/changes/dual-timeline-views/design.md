## Context

The QuickHeadlines application currently has two main views:
1. **Feed Box View**: Shows feeds organized by their configured source, with items grouped by feed
2. **Timeline View**: Shows a global chronological stream of ALL items from ALL feeds, ignoring tab selection

Users want a third view option that provides chronological ordering but limited to only the currently selected feed tab. This requires architectural changes to support tab-specific timeline data fetching and state management, along with UI updates for navigation and icons.

Current constraints:
- Must maintain backward compatibility with existing functionality
- Must work within the existing Svelte 5 + Crystal backend architecture
- Must respect the Nix/FreeBSD compatibility requirements
- Should leverage existing data caching and WebSocket update mechanisms

## Goals / Non-Goals

**Goals:**
- Implement a tab-specific timeline view that shows only items from the currently selected feed tab in chronological order
- Rename existing timeline to "Global Timeline" with globe icon for clear distinction
- Update feed box view icon to box/package symbol for better visual representation
- Maintain seamless navigation between all three views with proper URL routing
- Preserve existing data loading, caching, and real-time update behaviors
- Ensure responsive design works across all view modes

**Non-Goals:**
- Changing the underlying database schema or clustering logic
- Modifying the existing global timeline functionality beyond renaming and icon updates
- Adding new configuration options to feeds.yml for this feature
- Implementing complex filtering or search within the new timeline view

## Decisions

**1. API Endpoint Strategy**
- **Decision**: Extend existing `/api/timeline` endpoint with optional `tab` parameter rather than creating new endpoint
- **Rationale**: Minimizes backend changes, leverages existing timeline query logic, maintains consistency with feed API pattern (`/api/feeds?tab=tabname`)
- **Alternative Considered**: Create separate `/api/tab-timeline` endpoint - rejected due to code duplication and maintenance overhead

**2. State Management Approach**
- **Decision**: Extend existing `timelineStore.svelte.ts` to support tab-specific vs global modes rather than creating separate store
- **Rationale**: Both timeline views share the same core functionality (chronological sorting, infinite scroll, clustering), differing only in data scope
- **Alternative Considered**: Create separate `tabTimelineStore.svelte.ts` - rejected to avoid code duplication and complexity

**3. Navigation Architecture**
- **Decision**: Use URL-based routing with query parameters (`?view=global|tab|feed`) combined with existing tab parameter (`?tab=tabname`)
- **Rationale**: Maintains consistency with current navigation patterns, enables bookmarkable URLs, works with browser history
- **Implementation**: Three-way toggle between views while preserving current tab selection

**4. Icon Selection**
- **Decision**: Use emoji symbols directly in UI components for simplicity and immediate availability
  - Global Timeline: 🌐 (globe)
  - Feed Box View: 📦 (box/package)  
  - Tab Timeline: ⏱️ (stopwatch/clock)
- **Rationale**: No need for external icon libraries, consistent with minimal dependency philosophy, immediately recognizable

**5. Data Loading Strategy**
- **Decision**: Reuse existing `FeedCache` infrastructure with modified queries for tab-specific timeline
- **Rationale**: Leverages proven caching mechanism, maintains performance characteristics, minimizes new code

## Risks / Trade-offs

**[Performance Risk]** - Tab-specific timeline queries may be slower than global timeline if not properly optimized
→ **Mitigation**: Ensure database indexes exist on (tab_id, pub_date) combinations, test with realistic data volumes

**[UX Complexity Risk]** - Adding third view option may confuse users unfamiliar with the distinction
→ **Mitigation**: Clear labeling ("Global Timeline" vs "Timeline"), intuitive icons, consistent behavior patterns

**[Maintenance Risk]** - Extended timeline store may become complex with multiple modes
→ **Mitigation**: Keep mode-specific logic minimal, use clear separation of concerns, thorough testing

**[Mobile UX Risk]** - Three navigation icons may crowd mobile interface
→ **Mitigation**: Test responsive layouts, consider collapsible navigation on smaller screens if needed
## Why

The feeds view has critical bugs preventing proper feed display and causing resource leaks:
1. **Feed retrieval broken**: `lastUpdated` is never assigned from API response, causing cache validation failures and missing UI timestamps
2. **Tabs never initialized**: The `tabs` array is never populated from API response, breaking tab navigation
3. **Memory leaks**: Multiple refresh intervals run simultaneously, causing excessive API calls and resource waste
4. **Poor UX**: Aborted requests show error toasts, confusing users during normal tab switching

These issues block basic functionality and must be fixed before any further refactoring.

## What Changes

- **Fix feed data assignment**: Set `lastUpdated` from `response.updated_at` and `tabs` from `response.tabs` in feeds page
- **Consolidate refresh intervals**: Single source of truth for refresh logic, eliminating duplicate intervals
- **Fix AbortError handling**: Don't show toast notifications for cancelled requests (normal during tab switches)
- **Add request timeout**: 30-second timeout on feed fetch requests to prevent indefinite hangs
- **Add request deduplication**: Prevent concurrent identical feed requests

## Capabilities

### New Capabilities
None - this is a bug fix, not a new feature.

### Modified Capabilities
None - these are implementation fixes to restore intended behavior, not requirement changes.

## Impact

**Frontend Files**:
- `frontend/src/routes/+page.svelte` - Fix data assignment, consolidate intervals
- `frontend/src/lib/api.ts` - Fix error handling, add timeout and deduplication

**Behavior Changes**:
- Feed timestamps now display correctly
- Tab navigation works reliably
- Reduced API calls (no duplicate intervals)
- No error toasts for normal request cancellations
- Faster failure on network issues (30s timeout)

**No Breaking Changes** - All fixes restore intended functionality.

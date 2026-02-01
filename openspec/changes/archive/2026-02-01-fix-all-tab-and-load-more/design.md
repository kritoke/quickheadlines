## Context

The "All" tab in the Home view is currently broken because the backend handler in `src/api.cr` is case-sensitive and does not match "All" to "all". Additionally, the "Load More" button styling is inconsistent across views, and its visibility logic doesn't correctly use the `total_item_count` from the backend. The v0.4.0 design also requires a wider max-width for the desktop container.

## Goals / Non-Goals

**Goals:**
- Fix the "All" tab functionality by making the API handler case-insensitive.
- Standardize the "Load More" button appearance and behavior.
- Increase the maximum container width to 1600px for desktop.

**Non-Goals:**
- Refactoring the entire feed loading architecture.
- Changing how clustering or story groups work.

## Decisions

### 1. Case-Insensitivity in Backend
- **Decision**: Use `.downcase` on the `active_tab` parameter in both `src/controllers/api_controller.cr` and `src/api.cr`.
- **Rationale**: Ensures consistency regardless of whether the UI sends "all", "All", or any other variation.
- **Alternatives**: Forcing the UI to always send lowercase, but backend robustness is preferred.

### 2. "Load More" Visibility Logic
- **Decision**: Update `Home_.elm` to compare `List.length feed.items` with `feed.totalItemCount`.
- **Rationale**: This is the most accurate way to determine if more items exist.
- **Alternatives**: Relying on a fixed threshold (e.g., 10 items), but that fails if exactly 10 items exist.

### 3. Desktop Container Max-Width
- **Decision**: Update `Responsive.elm` to change `containerMaxWidth` for `DesktopBreakpoint` from 1200 to 1600.
- **Rationale**: Aligns with the v0.4.0 design specifications for a wider layout.

## Risks / Trade-offs

- **Risk**: Increasing max-width might affect layouts on smaller desktop screens.
- **Mitigation**: Verify that the grid adapts correctly (it already uses a chunked row layout with `DesktopBreakpoint -> 3` columns).

## Why

Desktop users experience inconsistent header styling between home and timeline views, creating a disjointed user experience. Additionally, the story clustering algorithm is too restrictive - it only groups stories with identical titles, missing opportunities to identify related stories with similar but not identical headlines. This reduces the value of clustering as a feature for news aggregation.

## What Changes

- **Header Consistency**: Align header styling, padding, and layout between home view and timeline view on desktop breakpoints (>=640px)
- **Clustering Algorithm**: Modify clustering similarity thresholds to identify related stories beyond exact title matches
- **Padding Improvements**: Increase horizontal padding on both sides of headers for better visual breathing room

## Capabilities

### New Capabilities
- `desktop-header-consistency`: Ensure uniform header styling, layout, and spacing across all views on desktop breakpoints

### Modified Capabilities
- `ui-styling`: Add requirements for consistent header styling between home and timeline views on desktop
- `hybrid-clustering`: Lower similarity thresholds or adjust clustering strategy to identify more related stories (not just exact matches)

## Impact

- Frontend: Elm components `Home_.elm` and `Timeline.elm` for header rendering
- CSS: Header styling rules in `assets/css/input.css`
- Backend: Clustering algorithm in Crystal backend
- User Experience: Improved visual consistency and more useful story grouping

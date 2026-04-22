## 1. Backend API Updates

- [x] 1.1 Modify timeline API endpoint to accept optional tab parameter
- [x] 1.2 Update SQL queries to filter timeline results by tab when parameter is provided
- [x] 1.3 Ensure existing global timeline functionality remains unchanged when tab parameter is not provided
- [x] 1.4 Test timeline API with various tab parameters and verify correct data filtering

## 2. Frontend State Management

- [x] 2.1 Extend timelineStore.svelte.ts to support tab-specific vs global modes
- [x] 2.2 Add view state management to track current view mode (feeds, tab-timeline, global-timeline)
- [x] 2.3 Update navigation store to handle three-way view switching with proper URL parameters
- [x] 2.4 Ensure seamless data loading and caching for both timeline modes

## 3. Navigation UI Implementation

- [x] 3.1 Update navigation component layout to include three view options
- [x] 3.2 Implement globe icon (🌐) for Global Timeline view  
- [x] 3.3 Implement box icon (📦) for Feed Box view
- [x] 3.4 Implement clock icon (⏱️) for Tab Timeline view
- [x] 3.5 Position Global Timeline icon to the left of view toggle but right of search

## 4. Routing and URL Management

- [x] 4.1 Update SvelteKit routing to handle view parameter in URLs
- [x] 4.2 Implement URL parameter parsing for view and tab states  
- [x] 4.3 Ensure bookmarkable URLs maintain both view mode and tab selection
- [x] 4.4 Test navigation history and browser back/forward buttons

## 5. Data Loading and Performance

- [x] 5.1 Implement tab-specific timeline data loading logic
- [x] 5.2 Ensure infinite scroll works correctly for both timeline modes
- [x] 5.3 Verify clustering logic respects tab boundaries for tab timeline
- [x] 5.4 Test performance with large datasets in both timeline modes

## 6. Testing and Validation

- [x] 6.1 Create unit tests for new timeline API functionality
- [x] 6.2 Create integration tests for view switching and data loading
- [x] 6.3 Test responsive design on mobile and desktop layouts
- [x] 6.4 Verify all three views work correctly with different tab selections
- [x] 6.5 Run full build and test suite to ensure no regressions

## 7. Documentation and Finalization

- [x] 7.1 Update any relevant documentation or comments
- [x] 7.2 Run final build with `just nix-build` and verify success
- [x] 7.3 Test complete user flow: switch tabs, switch views, verify correct content
- [x] 7.4 Prepare change for archival and merge
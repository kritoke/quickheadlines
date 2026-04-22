## Why

The current codebase contains unnecessary complexity and redundant features that make it harder to maintain and extend, while the core functionality (feed fetching, clustering, software releases, 10 themes with cursor trail) is already robust. This change aims to simplify the architecture by removing dead code, over-engineered abstractions, and rarely-used configuration options, making QuickHeadlines feel more "simple to use" and "just work" as intended.

## What Changes

### Backend Simplifications
- **Remove dead code**: Eliminate unused `cluster_uncategorized` method and consolidate state management
- **Simplify configuration**: Remove rarely-used config options (per-feed retry/timeout settings, rate limiting, HTTP client advanced settings, authentication support)
- **Keep essential features**: Software releases, clustering, cache management, and tabs organization remain intact

### Frontend Simplifications  
- **Remove unnecessary abstractions**: Eliminate design tokens system and unused UI components like `CustomScrollbar`
- **Consolidate logic**: Use unified WebSocket effects handler and simplified scroll management
- **Maintain core UI**: All 10 themes, cursor trail functionality, and clustering UI preserved

## Capabilities

### Modified Capabilities
- `feed-aggregation`: Simplified configuration options while maintaining core feed fetching functionality
- `clustering`: Consolidated to single LSH-based approach while preserving similarity detection quality
- `ui-theming`: Maintained all 10 themes and cursor trail functionality with simplified implementation

## Impact

- **Configuration**: Reduced from ~30 options to ~10 essential ones in `feeds.yml`
- **Codebase**: ~20-30% reduction in code complexity without feature loss
- **User Experience**: Simpler setup, faster builds, cleaner mental model
- **Maintainability**: Easier to extend and build new products on this foundation
- **Performance**: Slightly improved due to reduced overhead from removed abstractions
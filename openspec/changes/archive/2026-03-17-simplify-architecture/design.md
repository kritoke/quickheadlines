## Context

QuickHeadlines currently has a robust backend for feed fetching, clustering, and software releases, along with a feature-rich frontend supporting 10 themes and cursor trail functionality. However, the codebase contains redundant complexity including dead code, over-engineered abstractions, and rarely-used configuration options that make maintenance and extension more difficult than necessary.

## Goals / Non-Goals

**Goals:**
- Remove dead code and unused features to reduce cognitive load
- Simplify configuration to essential options only
- Maintain all core functionality (software releases, 10 themes, cursor trail, clustering)
- Improve code maintainability and build performance
- Preserve reliability and robustness of the feed aggregation system

**Non-Goals:**
- Adding new features or capabilities
- Changing the fundamental architecture or data models
- Modifying existing APIs or breaking backward compatibility
- Removing any core user-facing functionality

## Decisions

### Backend Simplifications
- **Remove `cluster_uncategorized` method**: This method exists but is never called; only `recluster_with_lsh` is used in production. Keeping both creates confusion without benefit.
- **Eliminate global state singletons**: Replace `STATE` and `FEED_CACHE` globals with proper dependency injection for better testability and thread safety.
- **Streamline configuration options**: Remove per-feed retry/timeout settings, rate limiting config, HTTP client advanced settings, and authentication support since these are rarely needed and complicate the user experience.

### Frontend Simplifications  
- **Keep design tokens for themes**: The theme-related tokens (`theme-bg-primary`, etc.) are essential for the 10-theme system and should be preserved. Only simplify spacing tokens if they add minimal value.
- **Consolidate WebSocket handlers**: Use a single WebSocket effect handler instead of separate handlers for feeds and timeline to reduce code duplication.
- **Simplify scroll management**: Rely on browser defaults instead of custom scroll position tracking to reduce complexity.

### Configuration Approach
- **Preserve software releases**: This is a core feature and will remain fully functional with all current capabilities.
- **Maintain clustering configuration**: Keep all clustering settings since this is essential functionality.
- **Keep essential cache management**: Retain `cache_retention_hours` and `max_cache_size_mb` as these are important for resource management.

## Risks / Trade-offs

[Risk] Users who have configured removed options may need to update their config files → Mitigation: Provide clear migration documentation and ensure defaults are sensible
[Risk] Removing some abstractions might make future feature additions slightly more verbose → Mitigation: The trade-off for simplicity and maintainability is worth it for the current scope
[Risk] Consolidating WebSocket handlers could introduce subtle timing issues → Mitigation: Thorough testing of real-time updates during implementation

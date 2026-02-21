## TODO

These are just possible features that could be added in the future, for now its just a brain dump.

### Minor Features/Configuration for Feeds

- Allow for a custom limit for each feed in yaml

### UI Features

- Add a search bar at the top of the page that can look through all the headlines on the feedbox page and have it go to that item immediately, having some indicator (highlight or similar).  Make it respect whichever tab it is in. 
    - Possibly have it do same thing on timeline view.
- Have a force refresh button somewhere, but rate limit it to prevent abuse.
- Add a button to clear the cache for a feed, or all feeds, but rate limit it to prevent abuse.

### Advanced Features

- Add Special Non-RSS Feed Features for Monitoring Certain Site Releases
    - Github Releases via repo name
    - Youtube Channel Releases via channel name

- Distinguish Commentary vs Direct Links for certain feeds
    - Hacker News: RSS has `<link>` (article) and `<comments>` (HN discussion)
    - Daring Fireball: JSON Feed has `external_url` (article) and `url` (DF commentary)
    - Add UI icon to indicate link type (e.g., 💬 for discussion, 🔗 for direct)
    - Parser changes needed to capture both link fields

### General Build/Deployment Features

---

## Improvements (2026-02-18)

### Clustering
- [x] Switch from MinHash to overlap coefficient for short text similarity
- [x] Lower threshold from 0.75 to 0.35 for better clustering
- [x] Make clustering run automatically after feed refresh
- [x] Implement duplicate detection at feed fetch time (skip if title exists)
- [ ] Add configurable clustering threshold in feeds.yml
- [ ] Consider using TF-IDF instead of simple word overlap

### UI/UX
- [ ] Add keyboard shortcuts for navigation
- [ ] Show feed last-updated timestamp
- [ ] Improve mobile layout for feed cards

### Performance
- [ ] Optimize database queries (add indexes)
- [ ] Precompute clustering during idle periods

### Features
- [ ] Add search functionality across all articles
- [ ] Support OPML import/export for feeds

### DevOps
- [ ] Add health check endpoint
- [ ] Add automated database backup

## Known Issues

- [ ] Clustering threshold may need tuning for different story types
- [ ] Some similar headlines don't cluster due to LSH candidate generation (overlap < 0.35)
- [ ] Server startup can be slow on first load (feeds need to be fetched)
- [ ] No way to manually refresh a single feed
- [ ] Database grows over time - need automated cleanup strategy

## Backlog

- [ ] Add unit tests for clustering service
- [ ] Improve error handling for malformed RSS feeds
- [ ] Add support for authenticated feeds

## Code Quality Investigation (2026-02-20)

Crystal MCP found 88 potentially unreachable methods. Review to determine if they are:
- Dead code that should be removed
- Useful utilities for future use
- Part of unused service/repository layers

### Files to Review

- [ ] `src/api.cr` - Multiple response classes and helper methods
  - ApiErrorResponse#initialize
  - ClustersResponse#initialize
  - ClusterResponse#initialize
  - Api.tab_to_response
  - Api.timeline_item_to_response
  - Api.generate_item_id
  - Api.to_unix_ms
  - Api.send_json
  - Api.send_error
  - Api.handle_feeds
  - Api.handle_feed_more
  - Api.handle_timeline
  - Api.handle_version

- [ ] `src/color_extractor.cr` - Color utility methods
  - ColorExtractor.calculate_dominant_color_from_buffer
  - ColorExtractor.luminance
  - ColorExtractor.contrast
  - ColorExtractor.find_dark_text_for_bg_public
  - ColorExtractor.find_light_text_for_bg_public
  - ColorExtractor.rgb_to_hex_public
  - ColorExtractor.test_calculate_dominant_color_from_buffer
  - ColorExtractor.auto_upgrade_to_auto_corrected
  - ColorExtractor.roles_meet_contrast
  - ColorExtractor.clear_cache
  - ColorExtractor.clear_theme_cache

- [ ] `src/config.cr` - Config parsing utilities
  - file_mtime
  - find_default_config
  - parse_config_arg
  - detect_github_repo
  - fetch_config_from_github
  - download_config_from_github

- [ ] `src/health_monitor.cr` - Health monitoring methods
  - HealthMonitor.log_health_metrics
  - HealthMonitor.start_monitoring
  - HealthMonitor.calculate_cpu_usage
  - HealthMonitor.format_bytes
  - HealthMonitor.feed_disabled?
  - HealthMonitor.disable_feed
  - HealthMonitor.get_feed_health
  - HealthMonitor.all_feed_health
  - HealthMonitor.log_feed_health

- [ ] `src/repositories/` - Repository layer (may be unused DTO/entity pattern)
  - FeedRepository methods
  - HeatMapRepository methods
  - StoryRepository methods

- [ ] `src/services/` - Service layer methods
  - ClusteringService#get_all_clusters_from_db
  - DatabaseService#close
  - HeatMapService methods

- [ ] `src/storage/` - Storage utility methods
  - ClusteringRepository methods
  - HeaderColorsRepository#update_feed_theme_colors
  - FeedCache#get_slice
  - FeedCache#entries
  - FeedCache#close
  - FeedCache#get_without_lock

- [ ] `src/utils.cr` - Utility functions
  - relative_time
  - current_date_fallback
  - last_updated_format

- [ ] `src/favicon_storage.cr` - Favicon utilities
  - FaviconStorage.convert_data_uri
  - FaviconStorage.clear
  - FaviconStorage.exists?

- [ ] `src/models.cr` - Model helper methods
  - to_clustered
  - FeedData#display_header_color
  - FeedData#display_header_text_color
  - AppState#feeds_for_tab
  - AppState#releases_for_tab
  - AppState#all_timeline_items
  - AppState#update

- [ ] `src/listeners/heat_map_listener.cr` - Event listener
  - HeatMapListener methods

---

## Pre-Release Code Audit (2026-02-21)

### CRITICAL - Must Fix Before Release

- [x] **XSS Risk in CoolMode.svelte** (`frontend/src/lib/components/CoolMode.svelte:101,105`)
  - Uses `innerHTML` with user data: `particle.innerHTML = \`<img src="${particleType}">\``
  - Fix: Sanitize `particleType` or use DOM API

- [x] **Remove Svelte 4 Lifecycle Hooks**
  - `frontend/src/routes/+page.svelte` - remove `onMount` import/usage
  - `frontend/src/routes/timeline/+page.svelte` - remove `onMount` import/usage  
  - `frontend/src/routes/+layout.svelte` - remove `onMount` import/usage
  - `frontend/src/lib/components/CoolMode.svelte` - remove `onMount`, `onDestroy` imports
  - Replace with Svelte 5 `$effect` (already partially done)

### HIGH - Should Fix

- [x] **Debug Code Remnants**
  - `src/services/clustering_service.cr:128,138,142` - `STDERR.puts` with `ENV["DEBUG_CLUSTERING"]?`
  - `src/api.cr:418-454` - Debug logging guarded by `config.debug?`
  - `src/utils.cr:10` - `STDOUT.puts "[DEBUG]"` function
  - Note: These are intentionally guarded debug features, kept for troubleshooting

- [x] **Deprecated Crystal `.not_nil!`**
  - `src/controllers/api_controller.cr:431` - request body
  - `src/storage/cleanup.cr:98` - raw value

- [x] **Console Logging in Frontend** (affects production)
  - `frontend/src/routes/+page.svelte:79,96,108` - console.error/log/warn
  - `frontend/src/routes/timeline/+page.svelte:41,72,128` - console methods
  - `frontend/src/lib/components/TimelineView.svelte:51` - console.error

### MEDIUM - Technical Debt

- [x] **Unimplemented Repository/Service Code**
  - `src/repositories/feed_repository.cr` - 4 unimplemented methods
  - `src/repositories/story_repository.cr` - 3 unimplemented methods
  - `src/repositories/heat_map_repository.cr` - 3 unimplemented methods
  - `src/services/heat_map_service.cr` - 2 unimplemented methods
  - Document or remove this dead code

### DOCKER/GITHUB ISSUES

- [x] **Dockerfile:80** - `if [ ! -f /feeds.yml ]` condition won't work as expected
- [x] **Dockerfile** - No non-root user, no HEALTHCHECK
- [x] **CI tests.yml** - Only runs 2 spec files, not full test suite
- [x] **CI docker-image.yml** - Missing proper error handling for build failures

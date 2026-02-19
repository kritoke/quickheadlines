# Changelog

## [0.5.0] - Unreleased

### Added

- **Athena Framework Backend**: Migrated from custom Crystal backend to Athena framework for improved routing and maintainability
- **Svelte 5 Frontend**: Rebuilt frontend with Svelte 5 using BakedFileSystem for embedded assets (single binary deployment)
- **Cool Mode Particle Effects**: Optional visual particle effects toggle
- **Vitest Testing**: Frontend unit tests with @testing-library/svelte
- **Config Change Detection**: Frontend periodically polls for feeds.yml changes without requiring server restart
- **Automatic Clustering**: Story clustering now runs automatically after each feed refresh
- **Duplicate Detection**: Skip items that already exist with the same title from the same feed

### Changed

- **Build System**: Migrated from Makefile to Justfile for better cross-platform developer experience
- **Clustering Algorithm**: Replaced MinHash with overlap coefficient for better short text matching
- **Clustering Threshold**: Lowered default threshold from 0.75 to 0.35 for more clusters
- **Fast Server Startup**: Improved startup logic to serve cached content immediately while fetching new feed items in background
- **Color Calculations**: Improved header color extraction algorithm for better feed branding
- **Animations**: Added animated theme toggle with smooth transitions
- **Feed Box Styling**: Improved responsive layout and visual styling for feed cards
- **CI/CD**: Updated workflows for Svelte 5 build pipeline

## [0.4.0] - 2026-01-16

### Added

- **Timeline View**: New timeline page showing all feed items in chronological order with day grouping and timestamps
- **HTTP Client Configuration**: Global HTTP client settings for timeout, connection timeout, and custom User-Agent
- **Authentication Support**: Feed authentication with support for Basic, Bearer token, and API Key authentication
- **Per-Feed Item Limits**: Configure individual feed item limits to override global default
- **Retry Logic**: Automatic retry with exponential backoff for failed feed fetches
- **Feed Validation**: Enhanced feed validation with better error messages
- **Health Monitoring**: Built-in health monitoring with CPU spike detection and error logging
- **Watchdog Timer**: Automatic detection and logging of hung refresh operations
- **Timeline Caching**: Cached timeline view with 30-second TTL for improved performance
- **Database Integrity Checks**: Automatic integrity checks on startup with repair capability
- **Configurable Cache Retention**: Set custom cache retention hours in feeds.yml (default: 168 hours)
- **Size-Based Cleanup**: Automatic cleanup of oldest entries when database exceeds 100MB

### Changed

- **Favicon Storage**: Serve favicons as static files instead of base64 data URIs for better performance
- **Favicon Resolution**: Improved favicon resolution for CDN/Cloudflare feeds
- **Mobile Layout**: Enhanced text, colors, and layout for better mobile experience
- **Dark Mode**: Improved timeline date styling for better contrast in dark mode
- **Container Support**: Added Linux/FreeBSD container fixes for better deployment

### Fixed

- **Gray Icon Fix**: Added Google favicon fallback for feeds with gray or missing icons
- **Favicon Redirects**: Fixed favicon redirect handling to properly follow redirects
- **Feed Box Text**: Removed "Fallback to Google favicon service" text from feed boxes view
- **Bastille Template**: Fixed template bugs for FreeBSD jail deployment

## [0.3.3] - 2026-01-07

### Fixed

- **Memory Leak**: Fixed memory leak from feed data not being cleared between refreshes.
  - Old feed data now properly cleared before populating with new data to prevent continuous memory growth over time.

## [0.3.2] - 2026-01-06

### Added

- Favicon cache with 100MB limit and 7-day expiration

## [0.3.1] - 2025-12-31

### Added

- **Explicit 404 Handling**: Added a proper 404 Not Found response for unknown routes in server.

### Fixed

- **403 Forbidden Errors**: Resolved access issues for feeds by enhancing HTTP headers (`Accept-Language`, `Connection`) and updating legacy URLs.

### Changed

- **Server Refactoring**: Optimized routing logic in `server.cr` to improve performance and code clarity.
- **HTTP Compression**: Enabled Gzip/Deflate support for all outgoing fetcher requests in `utils.cr` to reduce bandwidth usage.

## [0.3.0] - 2025-12-30

### Added

- **Redirect Support**: The fetcher now follows up to 10 redirects for both RSS feeds and favicon images.
- **Namespace-Agnostic Parsing**: Improved RSS/Atom parsing using `local-name()` to support feeds with custom XML namespaces (e.g., Sophos, Krebs on Security).

### Fixed

- **Favicon Fetching**: Resolved a crash caused by an invalid binary read method; implemented proper `IO::Memory` buffering.
- **Icon Visibility**: Added a styled "tile" background and border for favicons to ensure visibility on headers with matching brand colors.
- **Double Escaping**: Fixed an issue where favicon URLs were being escaped twice, breaking image proxy links.
- **Header Fallbacks**: Removed forced inline transparency on headers to allow CSS fallback colors to show while adaptive picker is loading.

### Changed

- **Color Algorithm**: Reverted adaptive color picker to prefer dominant icon colors over high-vibrancy colors for a more consistent, muted aesthetic.
- **User-Agent**: Switched to a modern browser User-Agent string to prevent being blocked by security-conscious sites.
- **Build System**: Updated to Makefile and Docker configuration to use standalone Tailwind CLI and improved ARM64 stability.

## [0.2.2] - 2025-12-30

### Added

- **Namespace-Agnostic Parsing**: Switched to `local-name()` XPath queries to handle feeds with custom XML namespaces (e.g., Sophos, Krebs).
- **Browser User-Agent**: Updated the fetcher to use a modern browser string to avoid being blocked by security-conscious sites.

### Fixed

- **Adaptive Colors**: Implemented a vibrancy-based color selection algorithm to better extract brand colors from icons (later refined in 0.2.3).
- **CSS Fallbacks**: Added default background colors for feed headers to prevent transparency issues during load.

## [0.2.1] - 2025-12-29

### Added

- **Redirect Handling**: Implemented automatic following of HTTP redirects for RSS feeds and favicons.
- **CORS Support**: Added `Access-Control-Allow-Origin` headers to the image proxy for browser-side color extraction.

### Fixed

- **Favicon Fetching**: Fixed a crash in binary data reading by using `IO::Memory` buffers.

## [0.2.0] - 2025-12-27

### Added

- **Tab Feature**: Feeds can now be organized into custom categories (e.g., "Tech", "Dev") via `feeds.yml`.
- **Enhanced Navigation**: Re-added scrollbars with high-contrast thumbs and implemented a bottom shadow indicator for light mode to ensure content visibility in Safari and other browsers.

### Fixed

- **UTF-8 Encoding**: Resolved issues with special characters (e.g., "Ÿnsect") in feed titles by updating the XML parser options.

### Changed

- **Mobile Responsiveness**: Improved layout handling and spacing for a better experience on smaller screens.

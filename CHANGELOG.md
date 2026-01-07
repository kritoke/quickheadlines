# Changelog

## [0.2.6] - 2026-01-07

### Fixed
- **Memory Leak**: Fixed memory leak from feed data not being cleared between refreshes.
  - Old feed data now properly cleared before populating with new data to prevent continuous memory growth over time.

## [0.2.5] - 2026-01-06

### Added
- Favicon cache with 100MB limit and 7-day expiration

### Fixed
- Correct shard build target

## [0.2.4] - 2025-12-31

### Added
- **Explicit 404 Handling**: Added a proper 404 Not Found response for unknown routes in the server.

### Fixed
- **403 Forbidden Errors**: Resolved access issues for feeds by enhancing HTTP headers (`Accept-Language`, `Connection`) and updating legacy URLs.

### Changed
- **Server Refactoring**: Optimized routing logic in `server.cr` to improve performance and code clarity.
- **HTTP Compression**: Enabled Gzip/Deflate support for all outgoing fetcher requests in `utils.cr` to reduce bandwidth usage.

## [0.2.3] - 2025-12-30

### Added
- **Redirect Support**: The fetcher now follows up to 10 redirects for both RSS feeds and favicon images.
- **Namespace-Agnostic Parsing**: Improved RSS/Atom parsing using `local-name()` to support feeds with custom XML namespaces (e.g., Sophos, Krebs on Security).

### Fixed
- **Favicon Fetching**: Resolved a crash caused by an invalid binary read method; implemented proper `IO::Memory` buffering.
- **Icon Visibility**: Added a styled "tile" background and border for favicons to ensure visibility on headers with matching brand colors.
- **Double Escaping**: Fixed an issue where favicon URLs were being escaped twice, breaking the image proxy links.
- **Header Fallbacks**: Removed forced inline transparency on headers to allow CSS fallback colors to show while the adaptive picker is loading.

### Changed
- **Color Algorithm**: Reverted the adaptive color picker to prefer dominant icon colors over high-vibrancy colors for a more consistent, muted aesthetic.
- **User-Agent**: Switched to a modern browser User-Agent string to prevent being blocked by security-conscious sites.
- **Build System**: Updated the Makefile and Docker configuration to use the standalone Tailwind CLI and improved ARM64 stability.

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

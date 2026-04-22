## ADDED Requirements

### Requirement: Favicon Storage Uses Absolute Paths

The FaviconStorage module SHALL store favicons using an absolute path computed at runtime from the cache directory environment variable or default cache location.

#### Scenario: Favicon path computed from QUICKHEADLINES_CACHE_DIR
- **WHEN** the environment variable `QUICKHEADLINES_CACHE_DIR` is set to `/var/cache/quickheadlines`
- **THEN** `FaviconStorage::FAVICON_DIR` SHALL equal `/var/cache/quickheadlines/favicons`

#### Scenario: Favicon path defaults to user cache directory
- **WHEN** `QUICKHEADLINES_CACHE_DIR` is not set
- **THEN** `FaviconStorage::FAVICON_DIR` SHALL use `$HOME/.cache/quickheadlines/favicons`

#### Scenario: Favicon directory created if missing
- **WHEN** `FaviconStorage.init` is called
- **THEN** the favicon directory SHALL be created if it does not exist

#### Scenario: Favicon save uses absolute path
- **WHEN** a favicon is saved via `FaviconStorage.save_favicon`
- **THEN** the file SHALL be written to `{FAVICON_DIR}/{hash}.{ext}`

#### Scenario: Favicon retrieval finds files by absolute path
- **WHEN** `FaviconStorage.get_or_fetch` is called for a cached URL
- **THEN** the path `/favicons/{hash}.{ext}` SHALL be returned if the file exists

### Requirement: Favicon Initialization Before Server Start

The application SHALL initialize FaviconStorage before the HTTP server accepts connections.

#### Scenario: FaviconStorage initialized at startup
- **WHEN** the application starts
- **THEN** `FaviconStorage.init` SHALL be called during bootstrap before `ATH.run`

#### Scenario: Fallback initialization on first favicon access
- **WHEN** a favicon is accessed before explicit initialization
- **THEN** `FaviconStorage.init` SHALL be called automatically

### Requirement: Favicon Path Migration Support

The system SHALL support migrating existing favicons from old relative paths to new absolute paths.

#### Scenario: Old favicon files migrated on startup
- **WHEN** `public/favicons/` directory exists and new `FAVICON_DIR` is different
- **THEN** existing favicon files SHALL be moved to the new absolute path location

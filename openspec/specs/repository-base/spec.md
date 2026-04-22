## ADDED Requirements

### Requirement: Shared repository constructor
All database repositories SHALL inherit from `QuickHeadlines::Repositories::RepositoryBase`, which SHALL accept either a `DatabaseService` or `DB::Database` and extract the underlying `DB::Database` instance.

#### Scenario: Repository initialized with DatabaseService
- **WHEN** a repository is constructed with a `DatabaseService` instance
- **THEN** `@db` SHALL be set to `db_service.db`

#### Scenario: Repository initialized with DB::Database
- **WHEN** a repository is constructed with a raw `DB::Database` instance
- **THEN** `@db` SHALL be set to the provided database instance

### Requirement: Shared time parsing helper
`QuickHeadlines::CacheUtils` SHALL provide a `parse_db_time` class method that parses a nullable string using `Constants::DB_TIME_FORMAT` and `Time::Location::UTC`.

#### Scenario: Valid time string
- **WHEN** `parse_db_time` is called with a valid formatted string
- **THEN** it SHALL return a `Time` instance

#### Scenario: Nil input
- **WHEN** `parse_db_time` is called with `nil`
- **THEN** it SHALL return `nil`

#### Scenario: Invalid format
- **WHEN** `parse_db_time` is called with an unparseable string
- **THEN** it SHALL return `nil`

### Requirement: SQL placeholder generation
`QuickHeadlines::CacheUtils` SHALL provide a `placeholders` class method that generates a comma-separated string of `?` characters for a given count.

#### Scenario: Generate placeholders
- **WHEN** `placeholders(3)` is called
- **THEN** it SHALL return `"?"` repeated 3 times joined by commas

### Requirement: Config URL collection
The `Config` struct SHALL provide an `all_feed_urls` method that returns all feed URLs from both top-level feeds and tab feeds as a single `Array(String)`.

#### Scenario: Config with feeds and tabs
- **WHEN** a config has 2 top-level feeds and 1 tab with 3 feeds
- **THEN** `all_feed_urls` SHALL return an array of 5 URLs

#### Scenario: Config with no tabs
- **WHEN** a config has feeds but no tabs
- **THEN** `all_feed_urls` SHALL return only the top-level feed URLs

### Requirement: Dead code removal
The following files/modules SHALL be deleted as they have zero production usage:
- `src/storage/clustering_repo.cr` (ClusteringRepository module)
- `src/storage/cleanup.cr` (CleanupRepository module)
- Legacy `FeedCache` class stub in `src/models.cr` (lines 170-180)

#### Scenario: Build succeeds after deletion
- **WHEN** dead code files are removed
- **THEN** `crystal build` SHALL succeed without errors

#### Scenario: Tests pass after deletion
- **WHEN** dead code is removed and the cleanup spec is updated to use CleanupStore
- **THEN** all Crystal specs SHALL pass

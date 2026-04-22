## ADDED Requirements

### Requirement: Storage modules SHALL be organized in src/storage/ directory
The storage code SHALL be split into focused modules under `src/storage/` for better maintainability and context efficiency.

#### Scenario: Cache utilities module exists
- **WHEN** developer requires `./storage/cache_utils`
- **THEN** system provides `get_cache_dir`, `get_cache_db_path`, `normalize_feed_url`, `get_db_size`, `format_bytes`, `log_db_size`, `ensure_cache_dir`, `get_db` functions

#### Scenario: Database module exists
- **WHEN** developer requires `./storage/database`
- **THEN** system provides `create_schema`, `check_db_integrity`, `check_db_health`, `repair_database`, `repopulate_database`, `init_db`, `DbHealthStatus`, `DbRepairResult` types

#### Scenario: FeedCache module exists
- **WHEN** developer requires `./storage/feed_cache`
- **THEN** system provides `FeedCache` class with all CRUD operations

#### Scenario: Clustering repository module exists
- **WHEN** developer requires `./storage/clustering_repo`
- **THEN** system provides clustering database operations: `find_all_items_excluding`, `find_by_keywords`, `assign_cluster`, `store_item_signature`, `get_item_signature`, `store_lsh_bands`, `find_lsh_candidates`, `clear_clustering_metadata`, `get_cluster_items`, `get_cluster_size`, `cluster_representative?`

### Requirement: Backward compatibility SHALL be maintained for storage requires
Existing code requiring `./storage` SHALL continue to work without modifications.

#### Scenario: Legacy require path works
- **WHEN** code has `require "./storage"`
- **THEN** all storage functions and classes remain accessible

#### Scenario: No behavioral changes
- **WHEN** storage modules are split
- **THEN** all existing tests pass without modification

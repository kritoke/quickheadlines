## ADDED Requirements

### Requirement: Single DI type for repositories and services
Repositories and services SHALL accept only `DatabaseService` as their database dependency. The `DB::Database` union type SHALL be removed from `RepositoryBase` and `ClusteringService`.

#### Scenario: RepositoryBase accepts only DatabaseService
- **WHEN** a repository class is instantiated
- **THEN** it accepts `DatabaseService` as its database parameter
- **THEN** no case/when dispatch on the type is needed

#### Scenario: ClusteringService accepts only DatabaseService
- **WHEN** `ClusteringService` is instantiated
- **THEN** it accepts `DatabaseService` only

#### Scenario: All callers pass DatabaseService
- **WHEN** a repository or service is constructed anywhere in the codebase
- **THEN** `DatabaseService` is passed, never raw `DB::Database`

### Requirement: Admin operations go through store/repository layer
`AdminController` SHALL NOT execute raw SQL via `cache.db`. All data operations SHALL go through store or repository methods.

#### Scenario: No raw SQL in AdminController
- **WHEN** `AdminController` needs to perform data operations
- **THEN** it calls methods on `FeedCache`, stores, or repositories
- **THEN** no `db.exec` or `db.query` calls exist in the controller

### Requirement: Single refresh guard using StateStore
The refresh loop SHALL use only `StateStore.refreshing?` / `StateStore.refreshing=` for tracking refresh state. The `REFRESH_IN_PROGRESS` Atomic SHALL be removed.

#### Scenario: Refresh state uses StateStore exclusively
- **WHEN** a refresh cycle starts
- **THEN** `StateStore.refreshing = true` is set
- **THEN** on completion or error, `StateStore.refreshing = false` is guaranteed via `ensure` block

#### Scenario: REFRESH_IN_PROGRESS removed
- **WHEN** `refresh_loop.cr` is compiled
- **THEN** no `REFRESH_IN_PROGRESS` constant exists

### Requirement: Config hot-reload validates before applying
The refresh loop's config reload SHALL use `load_validated_config` instead of `load_config`. Invalid configs SHALL be rejected with a log message, keeping the current config active.

#### Scenario: Valid config reload
- **WHEN** the config file changes and is reloaded
- **THEN** `load_validated_config` is called
- **THEN** the new config is applied

#### Scenario: Invalid config rejected
- **WHEN** the config file is malformed
- **THEN** the reload is skipped
- **THEN** an error is logged
- **THEN** the previous config remains active

### Requirement: All public API endpoints have rate limiting
All public GET API endpoints SHALL call `check_rate_limit!` before processing.

#### Scenario: Config endpoint rate limited
- **WHEN** `GET /api/config` is called
- **THEN** `check_rate_limit!` is called before returning data

#### Scenario: Tabs endpoint rate limited
- **WHEN** `GET /api/tabs` is called
- **THEN** `check_rate_limit!` is called before returning data

#### Scenario: Cluster endpoints rate limited
- **WHEN** `GET /api/clusters` or `GET /api/clusters/{id}/items` is called
- **THEN** `check_rate_limit!` is called before returning data

#### Scenario: Favicon endpoint rate limited
- **WHEN** `GET /api/favicon.png` is called
- **THEN** `check_rate_limit!` is called before fetching

### Requirement: ClusteringService instantiated once per refresh cycle
The refresh loop SHALL create a single `ClusteringService` instance and pass it to all clustering operations, rather than creating a new instance per item.

#### Scenario: Single service instance for clustering
- **WHEN** items are processed for clustering during a refresh cycle
- **THEN** one `ClusteringService` instance is created and reused
- **THEN** no `ClusteringService.new` call exists inside the per-item loop

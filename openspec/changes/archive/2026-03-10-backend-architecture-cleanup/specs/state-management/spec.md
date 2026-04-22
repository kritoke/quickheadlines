## ADDED Requirements

### Requirement: Single AppState class definition
The system SHALL provide exactly one `AppState` class that provides access to application state through `StateStore`.

#### Scenario: AppState class exists and is unique
- **WHEN** code references `AppState`
- **THEN** there is exactly one class definition
- **AND** all state access methods delegate to `StateStore`

#### Scenario: AppState provides both instance and class methods
- **WHEN** code accesses state
- **THEN** both instance methods (via `STATE`) and class methods (via `AppState.method`) work identically
- **AND** both return the same underlying state

### Requirement: Thread-safe state access
The system SHALL provide thread-safe access to application state through `StateStore` with proper mutex synchronization.

#### Scenario: Concurrent state reads are safe
- **WHEN** multiple threads read state simultaneously
- **THEN** all reads complete without deadlock
- **AND** all reads return consistent state

#### Scenario: Concurrent state updates are serialized
- **WHEN** multiple threads attempt to update state simultaneously
- **THEN** updates are applied atomically
- **AND** no partial updates occur

### Requirement: No fake locking primitives
The system SHALL NOT provide locking methods that do not actually lock.

#### Scenario: with_lock method does not exist
- **WHEN** code attempts to call `AppState.with_lock`
- **THEN** the method does not exist
- **AND** the compiler raises an error

### Requirement: Explicit error handling
The system SHALL log all caught exceptions rather than silently swallowing them.

#### Scenario: Exceptions in feed fetching are logged
- **WHEN** an exception occurs during feed fetching
- **THEN** the exception is logged via `HealthMonitor.log_error`
- **AND** the exception details (class, message) are preserved

#### Scenario: JSON parsing errors are logged
- **WHEN** JSON parsing fails in theme extraction
- **THEN** the exception is logged
- **AND** execution continues with fallback values

### Requirement: Encapsulated fetcher logic
The system SHALL encapsulate feed fetching logic in a `FeedFetcher` class with instance methods.

#### Scenario: FeedFetcher class exists
- **WHEN** code needs to fetch feeds
- **THEN** a `FeedFetcher` class is available
- **AND** all fetcher-related methods are instance methods on this class

#### Scenario: FeedFetcher accepts cache dependency
- **WHEN** a `FeedFetcher` is instantiated
- **THEN** it accepts a `FeedCache` instance as a constructor parameter
- **AND** this enables testing with mock caches

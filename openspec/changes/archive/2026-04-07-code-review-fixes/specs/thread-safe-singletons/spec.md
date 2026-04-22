## ADDED Requirements

### Requirement: Thread-safe singleton initialization
Singleton services SHALL use mutex-based initialization to prevent multiple instances from being created concurrently.

#### Scenario: Concurrent instance access
- **WHEN** multiple fibers access a singleton's instance method simultaneously during first access
- **THEN** only one instance is created and all fibers receive the same instance

#### Scenario: Singleton instance never nil after first access
- **WHEN** the singleton instance has been initialized
- **THEN** subsequent accesses always return the same instance without locks

### Requirement: Singleton setter thread safety
Singleton setters SHALL be atomic to prevent partial updates visible to other fibers.

#### Scenario: Instance replaced while being used
- **WHEN** one fiber calls the singleton setter while another fiber calls getter
- **THEN** the getter receives either the old or new instance, never a partially initialized one

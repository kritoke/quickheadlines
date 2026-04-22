## ADDED Requirements

### Requirement: Service Registration
The system SHALL provide a DI container that allows services to be registered with their implementations.

#### Scenario: Register a service
- **WHEN** a service class is registered with the container
- **THEN** the container stores the service and its implementation

#### Scenario: Resolve a registered service
- **WHEN** a service is requested from the container
- **THEN** the container returns the registered implementation

### Requirement: Dependency Injection
The system SHALL inject dependencies into services through their constructors.

#### Scenario: Constructor injection
- **WHEN** a service is resolved from the container
- **THEN** all constructor dependencies are automatically resolved and injected

#### Scenario: Singleton services
- **WHEN** a service is registered as a singleton
- **THEN** the same instance is returned on every resolution

### Requirement: Request Context AppState
The system SHALL pass AppState through Athena's request context.

#### Scenario: Access AppState in controller
- **WHEN** a controller action is executed
- **THEN** the AppState is accessible via the request context

### Requirement: Replace Global Singletons
The system SHALL replace all class variable singletons with DI-managed services.

#### Scenario: DatabaseService injection
- **WHEN** DatabaseService is needed
- **THEN** it is obtained through DI, not class variable @@instance

#### Scenario: FeedFetcher injection
- **WHEN** FeedFetcher is needed
- **THEN** it is obtained through DI, not class variable @@instance

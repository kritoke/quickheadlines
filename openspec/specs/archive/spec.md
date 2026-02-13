# mint-async-patterns Specification

## Purpose
TBD - created by archiving change feedstore-fetch-decode-fix. Update Purpose after archive.
## Requirements
### Requirement: Mint compiler accepts async patterns
The Mint frontend SHALL use only verified working async patterns that the compiler accepts.

#### Scenario: Promise return type
- **WHEN** a function returns `Promise(Void)`
- **THEN** the compiler SHALL accept the function definition

#### Scenario: State update syntax
- **WHEN** a store function updates state
- **THEN** it SHALL use `next { field: value }` syntax with curly braces

#### Scenario: Type definitions compile
- **WHEN** record types are defined using `type` keyword
- **THEN** the compiler SHALL accept the definitions

### Requirement: FeedStore state management
The FeedStore SHALL manage feed data state for the frontend.

#### Scenario: Store definition compiles
- **WHEN** FeedStore is defined with state fields
- **THEN** the compiler SHALL accept the store definition

#### Scenario: State fields exist
- **WHEN** FeedStore is loaded
- **THEN** it SHALL have `feeds : Array(FeedSource)`, `loading : Bool`, and `theme : String` fields

#### Scenario: Load function exists
- **WHEN** `loadFeeds` function is called
- **THEN** it SHALL update loading state and initialize feeds

### Requirement: Api module provides fetch capability
The Api module SHALL provide functions for fetching data from the backend.

#### Scenario: Module definition compiles
- **WHEN** Api module is defined
- **THEN** the compiler SHALL accept the module definition

#### Scenario: Fetch function signature
- **fetchFeeds`WHEN** ` function is defined
- **THEN** it SHALL return `Promise(Array(FeedSource))`

#### Scenario: Decode function compiles
- **WHEN** `decodeFeedSources` function is defined
- **THEN** it SHALL accept `Array(Any)` and return `Array(FeedSource)`

### Requirement: Mint build passes
The frontend SHALL compile successfully with `mint build`.

#### Scenario: Build command succeeds
- **WHEN** `mint build --optimize` is run
- **THEN** it SHALL exit with code 0

#### Scenario: Bundle is generated
- **WHEN** build succeeds
- **THEN** it SHALL produce output files in the `dist/` directory

### Requirement: Documentation guides future development
The Mint guide SHALL provide actionable guidance for developers.

#### Scenario: Guide file exists
- **WHEN** `MINT_0_28_1_GUIDE.md` is read
- **THEN** it SHALL contain verified working patterns

#### Scenario: Anti-patterns are documented
- **WHEN** developers consult the guide
- **THEN** they SHALL know to avoid `sequence`, `await`, and `Promise.then(fun ...)` patterns

#### Scenario: Source reference provided
- **WHEN** developers need definitive syntax answers
- **THEN** the guide SHALL reference https://github.com/mint-lang/mint/tree/master/core/source


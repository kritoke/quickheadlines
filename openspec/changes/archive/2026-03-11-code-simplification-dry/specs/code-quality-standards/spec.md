## ADDED Requirements

### Requirement: DRY Utility Functions
The codebase SHALL use existing utility functions instead of duplicating functionality.

#### Scenario: Feed store cloning
- **WHEN** feedStore needs to clone an object
- **THEN** it MUST use the `deepClone` utility from `$lib/utils/clone` instead of `JSON.parse(JSON.stringify())`

#### Scenario: API error handling
- **WHEN** making API calls
- **THEN** the system SHOULD use a centralized fetch wrapper to eliminate repeated error handling patterns

### Requirement: Consolidated DTO Definitions
The codebase SHALL maintain data transfer objects in canonical locations to avoid duplication.

#### Scenario: StoryResponse definition
- **WHEN** creating a StoryResponse DTO
- **THEN** it MUST use the definition from `src/dtos/story_dto.cr` rather than duplicating the class definition elsewhere

### Requirement: Repository Entity Mapping
Repository classes SHALL extract common entity mapping logic into reusable private methods.

#### Scenario: Story entity mapping
- **WHEN** mapping database rows to Story entities
- **THEN** repositories SHOULD use a shared mapping method to ensure consistent field handling

### Requirement: Validation Logic
The codebase SHALL consolidate repetitive validation patterns into generic reusable methods.

#### Scenario: Numeric parameter validation
- **WHEN** validating numeric query parameters (limit, offset, days)
- **THEN** the system SHOULD use a single parameterized validation method with min/max bounds

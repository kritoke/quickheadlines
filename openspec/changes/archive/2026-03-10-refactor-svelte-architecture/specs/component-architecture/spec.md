## ADDED Requirements

### Requirement: Component Size Limits
Components SHALL follow size limits to maintain readability and testability.

#### Scenario: Page component size
- **WHEN** creating a new page component (+page.svelte)
- **THEN** the component SHALL NOT exceed 150 lines of script + template
- **AND** complex logic SHALL be extracted to stores or composables

#### Scenario: Component extracting child elements
- **WHEN** a component exceeds 150 lines
- **THEN** logically distinct UI sections SHALL be extracted to child components
- **AND** the parent component SHALL focus on composition

### Requirement: Single Responsibility Components
Each component SHALL have a focused, specific purpose.

#### Scenario: FeedBox component responsibility
- **WHEN** rendering a feed
- **THEN** FeedBox SHALL only handle feed display
- **AND** feed loading logic SHALL be in the feeds store
- **AND** feed item rendering SHALL be in a separate FeedCard component

#### Scenario: FeedHeader component
- **WHEN** rendering feed header
- **THEN** the header rendering SHALL be in a dedicated FeedHeader component
- **AND** it SHALL accept feed metadata as props

### Requirement: Reusable Composable Functions
Common patterns SHALL be extracted to composable functions.

#### Scenario: Search modal loading
- **WHEN** any component needs a search modal
- **THEN** it SHALL use a shared `useSearchModal()` composable
- **AND** the composable SHALL handle lazy loading, state, and callbacks

#### Scenario: Error handling
- **WHEN** any component makes an API call
- **THEN** it SHALL use a shared error handling pattern
- **AND** the error state and retry logic SHALL be consistent across components

#### Scenario: Loading states
- **WHEN** any component displays loading state
- **THEN** it SHALL use consistent loading indicators
- **AND** the loading state logic SHALL be reusable

### Requirement: Props Interface Definition
All components SHALL define explicit prop interfaces.

#### Scenario: Component props
- **WHEN** creating a new component
- **THEN** props SHALL be defined using TypeScript interface
- **AND** default values SHALL be provided where appropriate

#### Scenario: Event handlers
- **WHEN** a component accepts event handler props
- **THEN** event handlers SHALL be typed as proper function types
- **AND** optional handlers SHALL have proper optional notation

### Requirement: Key Usage in Each Blocks
All `#each` blocks SHALL use unique keys to prevent rendering issues.

#### Scenario: Each block with array index
- **WHEN** iterating over items that may have duplicate URLs or IDs
- **THEN** a composite key SHALL be used (e.g., `${item.url}-${index}`)
- **AND** simple index-only keys SHALL NOT be used for deduplicated lists

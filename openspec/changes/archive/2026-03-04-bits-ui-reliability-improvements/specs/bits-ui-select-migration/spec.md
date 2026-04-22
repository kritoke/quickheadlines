## ADDED Requirements

### Requirement: LayoutPicker Select Component
The LayoutPicker component SHALL use Bits UI Select for layout column selection.

#### Scenario: Display current column count
- **WHEN** the component renders
- **AND** the current timeline column count is N
- **THEN** the trigger button SHALL display N columns icon

#### Scenario: Open select dropdown
- **WHEN** user clicks the layout picker trigger
- **THEN** the Bits UI Select dropdown SHALL open
- **AND** display column options (1, 2, 3, 4 columns)

#### Scenario: Select new column count
- **WHEN** user selects a column option from the dropdown
- **AND** the new value is different from current
- **THEN** the timeline layout SHALL update to the new column count
- **AND** the dropdown SHALL close

#### Scenario: Select is accessible
- **WHEN** the Select component is used
- **AND** user navigates with keyboard
- **THEN** full keyboard navigation SHALL work (Arrow keys, Enter, Escape)
- **AND** screen readers SHALL announce the current selection and options

### Requirement: ThemePicker Bits UI Integration
The ThemePicker component SHALL properly use Bits UI Select with correct TypeScript types.

#### Scenario: Display current theme preview
- **WHEN** the ThemePicker renders
- **AND** the current theme is "dark"
- **THEN** the trigger SHALL show the dark theme preview swatch

#### Scenario: Select new theme
- **WHEN** user selects a theme from the dropdown
- **AND** the selected theme is valid
- **THEN** the application theme SHALL change to the selected theme
- **AND** the theme SHALL persist in localStorage

#### Scenario: Type safety for theme values
- **WHEN** TypeScript compiles the ThemePicker
- **THEN** no type casting (`as typeof themeState.theme`) SHALL be required
- **AND** invalid theme values SHALL be caught at compile time

### Requirement: ClusterExpansion Accordion Component
The ClusterExpansion component SHALL use Bits UI Accordion for similar stories display.

#### Scenario: Accordion header displays
- **WHEN** ClusterExpansion renders with items
- **THEN** an accordion header SHALL show "Similar stories (N)"

#### Scenario: Expand/collapse similar stories
- **WHEN** user clicks the accordion header
- **AND** the accordion is collapsed
- **THEN** the similar stories list SHALL expand
- **AND** clicking again SHALL collapse the list

#### Scenario: Accordion is accessible
- **WHEN** the Accordion component is used
- **AND** user navigates with keyboard
- **THEN** Enter/Space SHALL toggle expansion
- **AND** screen readers SHALL announce expand/collapse state

### Requirement: Backward Compatibility
The migrated components SHALL maintain backward compatibility with existing functionality.

#### Scenario: Layout state persists
- **WHEN** user selects a layout
- **AND** the page is refreshed
- **THEN** the selected layout SHALL be restored

#### Scenario: Theme state persists
- **WHEN** user selects a theme
- **AND** the page is refreshed
- **AND** the browser has localStorage
- **THEN** the selected theme SHALL be restored

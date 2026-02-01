# responsive-breakpoint-system Specification

## Purpose
TBD - created by archiving change refactor-responsive-layout. Update Purpose after archive.
## Requirements
### Requirement: Breakpoint type system
The system SHALL define a typed Breakpoint union with four tiers: VeryNarrow, Mobile, Tablet, Desktop.

#### Scenario: Breakpoint type exists
- **WHEN** Responsive module is imported
- **THEN** Breakpoint union type is available as VeryNarrow | Mobile | Tablet | Desktop

#### Scenario: Breakpoint is union type
- **WHEN** code references Breakpoint
- **THEN** type is a union type, not a string or integer

### Requirement: Breakpoint calculation from window width
The system SHALL provide a function to convert window width (pixels) to appropriate Breakpoint tier.

#### Scenario: Very narrow viewport
- **WHEN** window width is less than 480px
- **THEN** breakpointFromWidth returns VeryNarrow

#### Scenario: Mobile viewport
- **WHEN** window width is 480px to 767px
- **THEN** breakpointFromWidth returns Mobile

#### Scenario: Tablet viewport
- **WHEN** window width is 768px to 1023px
- **THEN** breakpointFromWidth returns Tablet

#### Scenario: Desktop viewport
- **WHEN** window width is 1024px or greater
- **THEN** breakpointFromWidth returns Desktop

### Requirement: Horizontal padding values
The system SHALL provide horizontal padding values for each breakpoint tier.

#### Scenario: Very narrow horizontal padding
- **WHEN** breakpoint is VeryNarrow
- **THEN** horizontalPadding returns 8

#### Scenario: Mobile horizontal padding
- **WHEN** breakpoint is Mobile
- **THEN** horizontalPadding returns 16

#### Scenario: Tablet horizontal padding
- **WHEN** breakpoint is Tablet
- **THEN** horizontalPadding returns 32

#### Scenario: Desktop horizontal padding
- **WHEN** breakpoint is Desktop
- **THEN** horizontalPadding returns 40

### Requirement: Vertical padding values
The system SHALL provide vertical padding values for each breakpoint tier.

#### Scenario: Very narrow vertical padding
- **WHEN** breakpoint is VeryNarrow
- **THEN** verticalPadding returns 8

#### Scenario: Mobile vertical padding
- **WHEN** breakpoint is Mobile
- **THEN** verticalPadding returns 16

#### Scenario: Tablet vertical padding
- **WHEN** breakpoint is Tablet
- **THEN** verticalPadding returns 32

#### Scenario: Desktop vertical padding
- **WHEN** breakpoint is Desktop
- **THEN** verticalPadding returns 60

### Requirement: Uniform padding values
The system SHALL provide uniform (all directions) padding values for each breakpoint tier.

#### Scenario: Very narrow uniform padding
- **WHEN** breakpoint is VeryNarrow
- **THEN** uniformPadding returns 8

#### Scenario: Mobile uniform padding
- **WHEN** breakpoint is Mobile
- **THEN** uniformPadding returns 16

#### Scenario: Tablet uniform padding
- **WHEN** breakpoint is Tablet
- **THEN** uniformPadding returns 32

#### Scenario: Desktop uniform padding
- **WHEN** breakpoint is Desktop
- **THEN** uniformPadding returns 96

### Requirement: Container max-width constraints
The system SHALL provide maximum width constraints for page containers based on breakpoint.

#### Scenario: Very narrow max-width
- **WHEN** breakpoint is VeryNarrow
- **THEN** containerMaxWidth returns fill (no maximum constraint)

#### Scenario: Mobile max-width
- **WHEN** breakpoint is Mobile
- **THEN** containerMaxWidth returns fill (no maximum constraint)

#### Scenario: Tablet max-width
- **WHEN** breakpoint is Tablet
- **THEN** containerMaxWidth returns maximum 1024

#### Scenario: Desktop max-width
- **WHEN** breakpoint is Desktop
- **THEN** containerMaxWidth returns maximum 1200

### Requirement: Breakpoint boolean helpers
The system SHALL provide helper functions to test breakpoint types.

#### Scenario: Very narrow detection
- **WHEN** breakpoint is VeryNarrow
- **THEN** isVeryNarrow returns true

#### Scenario: Mobile detection
- **WHEN** breakpoint is Mobile or VeryNarrow
- **THEN** isMobile returns true

#### Scenario: Tablet detection
- **WHEN** breakpoint is Tablet
- **THEN** isMobile returns false AND isVeryNarrow returns false

#### Scenario: Desktop detection
- **WHEN** breakpoint is Desktop
- **THEN** isMobile returns false AND isVeryNarrow returns false

### Requirement: Timeline element widths
The system SHALL provide responsive time column and cluster padding values for timeline components.

#### Scenario: Very narrow timeline time column
- **WHEN** breakpoint is VeryNarrow
- **THEN** time column width is 60px

#### Scenario: Not very narrow timeline time column
- **WHEN** breakpoint is Mobile, Tablet, or Desktop
- **THEN** time column width is 85px

#### Scenario: Very narrow cluster left padding
- **WHEN** breakpoint is VeryNarrow
- **THEN** expanded cluster left padding is 70px

#### Scenario: Not very narrow cluster left padding
- **WHEN** breakpoint is Mobile, Tablet, or Desktop
- **THEN** expanded cluster left padding is 105px

### Requirement: Responsive layout integration
The system SHALL allow all page components to use responsive helpers consistently.

#### Scenario: Timeline page uses responsive helpers
- **WHEN** Timeline.elm imports Responsive module
- **THEN** all padding, width, and layout values come from Responsive helpers
- **AND** component functions accept Breakpoint parameter

#### Scenario: Home page uses responsive helpers
- **WHEN** Home_.elm imports Responsive module
- **THEN** all padding, width, and layout values come from Responsive helpers
- **AND** component functions accept Breakpoint parameter

#### Scenario: Consistent behavior across pages
- **WHEN** both Timeline and Home use Responsive module
- **THEN** breakpoints trigger identical layout changes on both pages
- **AND** max-width constraints prevent cutoff on large screens

### Requirement: Header horizontal padding responsiveness
The system SHALL adjust header horizontal padding based on viewport width.

#### Scenario: Very narrow viewport header padding
- **WHEN** viewport width is less than 480px
- **THEN** header horizontal padding is 8px

#### Scenario: Mobile viewport header padding
- **WHEN** viewport width is between 480px and 767px
- **THEN** header horizontal padding is 16px

#### Scenario: Tablet viewport header padding
- **WHEN** viewport width is between 768px and 1023px
- **THEN** header horizontal padding is 32px

#### Scenario: Desktop viewport header padding
- **WHEN** viewport width is 1024px or greater
- **THEN** header horizontal padding is 96px

### Requirement: Header vertical padding consistency
The system SHALL maintain header vertical padding at 16px across all viewports.

#### Scenario: Header vertical padding on any viewport
- **WHEN** viewport width is any value
- **THEN** header vertical padding remains 16px

### Requirement: Navigation button visibility
The system SHALL ensure navigation buttons remain fully visible on all viewport sizes.

#### Scenario: Buttons on very narrow viewport
- **WHEN** viewport width is less than 480px
- **THEN** all navigation buttons are fully visible without cutoff

#### Scenario: Buttons on mobile viewport
- **WHEN** viewport width is between 480px and 767px
- **THEN** all navigation buttons are fully visible

#### Scenario: Buttons on tablet viewport
- **WHEN** viewport width is between 768px and 1023px
- **THEN** all navigation buttons are fully visible

#### Scenario: Buttons on desktop viewport
- **WHEN** viewport width is 1024px or greater
- **THEN** all navigation buttons are fully visible


## ADDED Requirements

### Requirement: Day headers shall use pill-styled design
Each day header in the timeline SHALL display inside a pill-shaped container with rounded corners and muted background color.

#### Scenario: Day header pill styling
- **WHEN** timeline renders
- **THEN** each day header appears as a row with an 8px circular orange accent dot followed by a rounded pill containing the date text

### Requirement: Day header shall use dayHeader typography
The date text within day headers SHALL use the `Ty.dayHeader` typography helper.

#### Scenario: Desktop dayHeader typography
- **WHEN** viewport width is ≥ 1024px
- **THEN** date text displays at 18px, semi-bold

#### Scenario: Tablet dayHeader typography
- **WHEN** viewport width is between 768px and 1023px
- **THEN** date text displays at 16px, semi-bold

#### Scenario: Mobile dayHeader typography
- **WHEN** viewport width is < 768px
- **THEN** date text displays at 14px, semi-bold

### Requirement: Day header shall use theme-aware background color
The pill background SHALL use the `dayHeaderBg` theme token which provides different colors for light and dark modes.

#### Scenario: Light mode day header background
- **WHEN** theme is Light
- **THEN** pill background color is rgb(245, 247, 249)

#### Scenario: Dark mode day header background
- **WHEN** theme is Dark
- **THEN** pill background color is rgb(30, 40, 54)

### Requirement: Day header shall display Today/Yesterday correctly
The day header SHALL display "Today" for the current date, "Yesterday" for the previous day, and formatted date otherwise.

#### Scenario: Today header
- **WHEN** the cluster date matches the current date
- **THEN** header displays "Today"

#### Scenario: Yesterday header
- **WHEN** the cluster date is one day before the current date
- **THEN** header displays "Yesterday"

#### Scenario: Past date header
- **WHEN** the cluster date is more than one day before the current date
- **THEN** header displays formatted date (e.g., "February 3, 2026")

### Requirement: Day header shall have subtle entry animation
Day headers SHALL fade and translate in with a 200ms ease-out transition when they appear.

#### Scenario: Day header entry animation
- **WHEN** day headers render on page load or scroll
- **THEN** they animate with opacity and transform over 200ms ease-out

# mobile-tab-navigation Specification

## Purpose
TBD - created by archiving change mobile-tab-bar-redesign. Update Purpose after archive.
## Requirements
### Requirement: Mobile tab bar displays with frosted glass effect
The mobile tab bar SHALL use a frosted glass aesthetic with backdrop blur to create visual separation from content below.

#### Scenario: Frosted glass renders correctly
- **WHEN** user views the mobile interface with feeds loaded
- **THEN** the tab bar displays with a blurred/translucent background that allows content beneath to be barely visible

### Requirement: Mobile tab bar has elevated shadow
The mobile tab bar SHALL have a soft shadow to create depth and separation from scrollable content.

#### Scenario: Shadow creates elevation
- **WHEN** user scrolls the feed content
- **THEN** the tab bar appears to float above the content with a visible shadow

### Requirement: Mobile tab bar uses theme-aware colors
The mobile tab bar SHALL use theme colors from the design system instead of hardcoded slate colors.

#### Scenario: Tab bar adapts to light theme
- **WHEN** user has selected a light theme
- **THEN** the tab bar uses appropriate light theme background and text colors

#### Scenario: Tab bar adapts to dark theme
- **WHEN** user has selected a dark theme
- **THEN** the tab bar uses appropriate dark theme background and text colors

#### Scenario: Tab bar adapts to custom theme
- **WHEN** user has selected a custom theme (e.g., Retro 80s, Matrix, Ocean)
- **THEN** the tab bar uses theme-appropriate colors from the selected theme

### Requirement: Mobile tab bar has adequate height for touch targets
The mobile tab bar SHALL have a minimum height of 64px to meet iOS touch target guidelines.

#### Scenario: Tab bar height provides comfortable tapping
- **WHEN** user taps on a tab
- **THEN** the tap target is at least 44px tall, making it comfortable to tap

### Requirement: Active tab shows filled pill background
The currently selected tab SHALL display with a filled pill-shaped background to clearly indicate selection.

#### Scenario: Active tab is visually distinct
- **WHEN** user has selected a specific tab (e.g., "tech")
- **THEN** the "tech" tab shows a filled background pill while other tabs show only text

#### Scenario: Active tab changes when selection changes
- **WHEN** user selects a different tab from the bottom sheet
- **THEN** the new active tab shows the filled pill background

### Requirement: Bottom sheet still functions for tab selection
The bottom sheet modal SHALL still open when the user taps the tab bar to change tabs.

#### Scenario: Tapping tab bar opens sheet
- **WHEN** user taps on the tab bar area
- **THEN** a bottom sheet appears showing all available tabs

#### Scenario: Selecting tab from sheet closes sheet and updates tab
- **WHEN** user taps a tab option in the bottom sheet
- **THEN** the bottom sheet closes and the selected tab becomes active


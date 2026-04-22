## ADDED Requirements

### Requirement: Mobile tab sheet shall appear as bottom sheet
On mobile viewports, tapping the tab selector SHALL open a bottom sheet overlay that slides up from the bottom of the screen.

#### Scenario: Bottom sheet slides up on tap
- **WHEN** user taps the mobile tab selector button
- **THEN** a bottom sheet slides up from the bottom of the screen with a smooth animation

#### Scenario: Bottom sheet displays full tab list
- **WHEN** bottom sheet is open
- **THEN** all available tabs are displayed as full-width buttons in a vertical list

### Requirement: Mobile tab sheet shall show active tab indicator
The bottom sheet SHALL clearly indicate which tab is currently active.

#### Scenario: Active tab shows checkmark
- **WHEN** bottom sheet is open AND a tab is active
- **THEN** the active tab displays a checkmark icon on the right side

#### Scenario: Active tab has visual highlight
- **WHEN** bottom sheet is open AND a tab is active
- **THEN** the active tab has a subtle background highlight (blue-50)

### Requirement: Mobile tab sheet shall close on selection
Selecting a tab in the bottom sheet SHALL close the sheet and update the active tab.

#### Scenario: Tab selection closes sheet
- **WHEN** user taps a tab in the bottom sheet
- **THEN** the bottom sheet closes AND the selected tab becomes active

#### Scenario: Sheet closes on backdrop tap
- **WHEN** user taps the backdrop area outside the bottom sheet
- **THEN** the bottom sheet closes without changing the active tab

#### Scenario: Sheet closes on escape key
- **WHEN** bottom sheet is open AND user presses Escape
- **THEN** the bottom sheet closes without changing the active tab

### Requirement: Mobile tab sheet shall have proper visual design
The bottom sheet SHALL follow mobile design conventions for appearance and interaction.

#### Scenario: Sheet has drag handle
- **WHEN** bottom sheet is open
- **THEN** a centered horizontal drag handle (pill shape) is visible at the top of the sheet

#### Scenario: Sheet has rounded top corners
- **WHEN** bottom sheet is open
- **THEN** the top corners are rounded (border-radius: 1rem or equivalent)

#### Scenario: Sheet has backdrop overlay
- **WHEN** bottom sheet is open
- **THEN** a semi-transparent black overlay (bg-black/50) covers the rest of the screen

### Requirement: Mobile tab sheet shall be accessible
The bottom sheet SHALL support screen reader navigation and keyboard interaction.

#### Scenario: Sheet has accessible label
- **WHEN** bottom sheet renders
- **THEN** it has an aria-label or aria-labelledby identifying it as "Select Category" or similar

#### Scenario: Sheet traps focus when open
- **WHEN** bottom sheet is open
- **THEN** keyboard focus is trapped within the sheet until it closes

## ADDED Requirements

### Requirement: Theme picker keyboard navigation
The theme picker dropdown SHALL support full keyboard navigation including opening with Enter/Space, closing with Escape, and navigating options with arrow keys.

#### Scenario: Open dropdown with keyboard
- **WHEN** user presses Enter or Space while focus is on theme picker trigger
- **THEN** dropdown opens and first theme is focused

#### Scenario: Close dropdown with Escape
- **WHEN** user presses Escape while dropdown is open
- **THEN** dropdown closes and focus returns to trigger button

#### Scenario: Navigate themes with arrow keys
- **WHEN** user presses Down Arrow while dropdown is open
- **THEN** focus moves to next theme option
- **AND** when reaching last option, focus wraps to first

### Requirement: Theme picker screen reader support
The theme picker SHALL provide proper ARIA attributes for screen reader users.

#### Scenario: Announce expanded state
- **WHEN** theme picker dropdown opens
- **THEN** aria-expanded is set to "true"
- **AND** when closed, aria-expanded is set to "false"

#### Scenario: Announce current selection
- **WHEN** screen reader reads theme picker
- **THEN** current theme name is announced
- **AND** selected theme shows checkmark indicator

### Requirement: Theme selection persists
Selected theme SHALL be saved to localStorage and restored on page reload.

#### Scenario: Save theme selection
- **WHEN** user selects a theme from dropdown
- **THEN** theme is saved to localStorage key "quickheadlines-theme"

#### Scenario: Restore theme on load
- **WHEN** page loads with saved theme in localStorage
- **THEN** saved theme is applied automatically
- **AND** theme picker shows correct selected theme

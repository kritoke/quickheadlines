# Specification: Timeline Day Header Styling

## Overview

This specification defines the visual styling for timeline day headers, ensuring consistent appearance across light and dark modes.

## Requirements

### Requirement: Day Header Background
Day headers SHALL use a subtle background color that provides visual hierarchy without being distracting.

#### Scenario: Light mode background
- **WHEN** viewing timeline in light mode
- **THEN** day headers have background color `#f1f5f9` (slate-100)
- **AND** text color is `#1e293b` (slate-800)

#### Scenario: Dark mode background
- **WHEN** viewing timeline in dark mode
- **THEN** day headers have background color `#1e2937` (slate-800)
- **AND** text color is `#f8fafc` (slate-50)

### Requirement: Day Header Padding
Day headers SHALL have consistent padding of 12px vertical and 16px horizontal.

#### Scenario: Consistent padding
- **WHEN** rendering any day header
- **THEN** padding is 12px top and bottom
- **AND** padding is 16px left and right

### Requirement: Day Header Border
Day headers SHALL include a subtle bottom border for visual separation.

#### Scenario: Bottom border styling
- **WHEN** rendering day headers
- **THEN** a 1px border is displayed at the bottom
- **AND** border color is `#e2e8f0` in light mode
- **AND** border color is `#334155` in dark mode

### Requirement: Date Text Styling
The date text SHALL be prominent with semi-bold weight.

#### Scenario: Date text appearance
- **WHEN** displaying the date
- **THEN** font weight is 600 (semi-bold)
- **AND** font size is 14px
- **AND** text is uppercase for day names (e.g., "MONDAY")

### Requirement: Consistent with Feed Headers
Day headers SHALL share visual language with feed card headers.

#### Scenario: Shared styling elements
- **WHEN** comparing day headers and feed headers
- **THEN** both use the same font family
- **AND** both use consistent border radius (4px)
- **AND** both transition smoothly on theme change

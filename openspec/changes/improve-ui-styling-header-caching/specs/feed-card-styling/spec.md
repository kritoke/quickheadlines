# Specification: Feed Card Styling

## Overview

This specification defines the styling requirements for feed cards on the home page, ensuring consistent appearance and proper dark mode support.

## Requirements

### Requirement: Card Padding
Feed cards SHALL have consistent padding of 12px on all sides.

#### Scenario: Consistent card padding
- **WHEN** rendering a feed card
- **THEN** padding is 12px on all sides
- **AND** padding is consistent across all cards

### Requirement: Header Area Styling
Feed card headers SHALL have consistent height and alignment.

#### Scenario: Header area appearance
- **WHEN** rendering a feed card header
- **THEN** header height is fixed at 44px minimum
- **AND** content is vertically centered
- **AND** favicon is 18x18px with 8px right margin

### Requirement: Title Typography
Feed titles SHALL use consistent font sizing and weight.

#### Scenario: Title appearance
- **WHEN** displaying feed titles
- **THEN** font size is 1.1rem (17.6px)
- **AND** font weight is 700 (bold)
- **AND** line height is 1.2

### Requirement: Dark Mode Text Contrast
Text colors SHALL have sufficient contrast in dark mode.

#### Scenario: Dark mode readability
- **WHEN** viewing in dark mode
- **THEN** text on light backgrounds has color `#1f2937`
- **AND** text on dark backgrounds has color `#f8fafc`
- **AND** contrast ratio meets WCAG AA standards (4.5:1)

### Requirement: Hover States
Interactive elements SHALL provide visual feedback on hover.

#### Scenario: Feed title hover
- **WHEN** hovering over a feed title link
- **THEN** text color changes to indicate interactivity
- **AND** cursor changes to pointer

### Requirement: Favicon Alignment
Favicons SHALL be consistently aligned across all cards.

#### Scenario: Favicon positioning
- **WHEN** rendering feed cards
- **THEN** all favicons are vertically centered
- **AND** favicons have consistent 8px right margin
- **AND** favicons maintain 18x18px dimensions

## ADDED Requirements

### Requirement: Favicon displays inline with site name
The UI SHALL render the site favicon inline with the site name in each timeline item. The favicon SHALL not be positioned above the site name under normal wrapping conditions.

#### Scenario: Standard desktop width
- **WHEN** the timeline is rendered at 1280px width with typical headline lengths
- **THEN** each timeline item displays the favicon immediately to the left of the site name, vertically centered with the headline text

#### Scenario: Narrow mobile width
- **WHEN** the timeline is rendered at 320px width and items wrap to multiple lines
- **THEN** the favicon remains inline with the site name (not floating above) and stays vertically aligned with the first line of the headline

### Requirement: Favicon sizing and accessibility
Favicons used in the timeline SHALL be 16x16 CSS pixels by default, scalable for high-DPI devices via source images or `srcset`. Images SHALL include `alt` text matching the site name for accessibility.

#### Scenario: High-DPI display
- **WHEN** the user is on a high-DPI display
- **THEN** the favicon appears sharp (via high-resolution assets) and maintains the same layout and alignment

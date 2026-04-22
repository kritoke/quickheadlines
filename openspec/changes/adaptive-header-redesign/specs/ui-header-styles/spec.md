## ADDED Requirements

### Requirement: Site header shall use hero typography
The site header title "Quick Headlines" SHALL display using the `Ty.hero` typography helper with semi-bold weight and 0.6 letter spacing across all breakpoints.

#### Scenario: Desktop header displays hero typography
- **WHEN** viewport width is ≥ 1024px
- **THEN** header title displays at 36px, semi-bold, with 0.6 letter spacing

#### Scenario: Tablet header displays hero typography
- **WHEN** viewport width is between 768px and 1023px
- **THEN** header title displays at 28px, semi-bold, with 0.6 letter spacing

#### Scenario: Mobile header displays hero typography
- **WHEN** viewport width is < 768px
- **THEN** header title displays at 20px, semi-bold, with 0.6 letter spacing

### Requirement: Header shall use theme-aware surface color
The header background SHALL use the `headerSurface` theme token which provides different colors for light and dark modes.

#### Scenario: Light mode header surface
- **WHEN** theme is Light
- **THEN** header background color is white (rgb(255, 255, 255))

#### Scenario: Dark mode header surface
- **WHEN** theme is Dark
- **THEN** header background color is rgb(24, 24, 24)

### Requirement: Header shall have subtle hairline border
The header SHALL display a 1px bottom border with a translucent color that adapts to the current theme.

#### Scenario: Light mode header border
- **WHEN** theme is Light
- **THEN** header border-bottom color is rgba(15, 23, 42, 0.06)

#### Scenario: Dark mode header border
- **WHEN** theme is Dark
- **THEN** header border-bottom color is rgba(255, 255, 255, 0.06)

### Requirement: Header shall use Inter variable font with system fallback
The header title SHALL use the "Inter var" font family with safe system fallbacks for consistent rendering.

#### Scenario: Font family applied correctly
- **WHEN** header renders
- **THEN** font-family is "Inter var", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial

## MODIFIED Requirements

### Requirement: Header shall use single-row layout with integrated tabs
The header SHALL display logo, tabs, and actions in a single row on desktop, with tabs adapting to a dropdown selector on mobile.

#### Scenario: Desktop header displays single row
- **WHEN** viewport width is ≥768px
- **THEN** header displays logo, inline tabs (up to 5), and action buttons all in one horizontal row

#### Scenario: Desktop header height is compact
- **WHEN** viewport width is ≥768px
- **THEN** header height is approximately 56px (h-14)

#### Scenario: Mobile header displays compact layout
- **WHEN** viewport width is <768px
- **THEN** header displays logo and actions on first row, tab selector button on second row

#### Scenario: Mobile header tab selector opens sheet
- **WHEN** user taps the tab selector on mobile
- **THEN** a bottom sheet opens with full tab list for selection

### Requirement: Header shall integrate tabs within header boundaries
Tabs SHALL be rendered within the header component rather than in a separate row below the header.

#### Scenario: Tabs render within header
- **WHEN** tabs are displayed
- **THEN** tabs render inside the header element, not in a separate div below

#### Scenario: Header CSS custom property updates on resize
- **WHEN** header renders or resizes
- **THEN** the `--header-height` CSS custom property is updated to reflect actual header height

## REMOVED Requirements

### Requirement: Header shall display tabs in separate row
**Reason**: Replaced by integrated single-row layout with adaptive tab selector. The old two-row design failed when too many tabs existed due to horizontal scrolling requirements.

**Migration**: Use the new `TabSelector` component which provides inline tabs on desktop with dropdown for overflow, and bottom sheet on mobile.

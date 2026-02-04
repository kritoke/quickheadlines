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

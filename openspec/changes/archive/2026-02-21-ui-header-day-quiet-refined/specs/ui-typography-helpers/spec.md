## ADDED Requirements

### Requirement: hero typography helper shall define responsive sizes
The `Ty.hero` helper SHALL return Elm font attributes that apply appropriate font sizes based on viewport width.

#### Scenario: Hero helper returns desktop size
- **WHEN** viewport width is ≥ 1024px
- **THEN** hero helper returns Font.size 36

#### Scenario: Hero helper returns tablet size
- **WHEN** viewport width is between 768px and 1023px
- **THEN** hero helper returns Font.size 28

#### Scenario: Hero helper returns mobile size
- **WHEN** viewport width is < 768px
- **THEN** hero helper returns Font.size 20

### Requirement: hero typography helper shall include consistent weight and spacing
The `Ty.hero` helper SHALL include semi-bold weight and 0.6 letter spacing.

#### Scenario: Hero includes weight and spacing
- **WHEN** hero helper is applied
- **THEN** the element has Font.semiBold and Font.letterSpacing 0.6

### Requirement: dayHeader typography helper shall define responsive sizes
The `Ty.dayHeader` helper SHALL return Elm font attributes that apply appropriate font sizes based on viewport width.

#### Scenario: dayHeader helper returns desktop size
- **WHEN** viewport width is ≥ 1024px
- **THEN** dayHeader helper returns Font.size 18

#### Scenario: dayHeader helper returns tablet size
- **WHEN** viewport width is between 768px and 1023px
- **THEN** dayHeader helper returns Font.size 16

#### Scenario: dayHeader helper returns mobile size
- **WHEN** viewport width is < 768px
- **THEN** dayHeader helper returns Font.size 14

### Requirement: dayHeader typography helper shall include consistent weight
The `Ty.dayHeader` helper SHALL include semi-bold weight.

#### Scenario: dayHeader includes weight
- **WHEN** dayHeader helper is applied
- **THEN** the element has Font.semiBold

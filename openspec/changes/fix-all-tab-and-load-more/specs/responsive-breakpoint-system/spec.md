## MODIFIED Requirements

### Requirement: Container max-width constraints
The system SHALL provide maximum width constraints for page containers based on breakpoint.

#### Scenario: Very narrow max-width
- **WHEN** breakpoint is VeryNarrow
- **THEN** containerMaxWidth returns fill (no maximum constraint)

#### Scenario: Mobile max-width
- **WHEN** breakpoint is Mobile
- **THEN** containerMaxWidth returns fill (no maximum constraint)

#### Scenario: Tablet max-width
- **WHEN** breakpoint is Tablet
- **THEN** containerMaxWidth returns maximum 1024

#### Scenario: Desktop max-width
- **WHEN** breakpoint is Desktop
- **THEN** containerMaxWidth returns maximum 1600

## ADDED Requirements

### Requirement: Particle burst on click
When the user clicks anywhere in the app (with effects enabled), a particle burst effect SHALL appear at the click location.

#### Scenario: Particles appear on click with effects enabled
- **WHEN** effects are enabled AND user clicks anywhere on the page
- **THEN** small particles explode outward from the click position

#### Scenario: No particles when effects disabled
- **WHEN** effects are disabled
- **THEN** clicking does not produce any particle effect

### Requirement: Particle visual design
The particle burst SHALL use the current theme's accent color.

#### Scenario: Particles use theme accent color
- **WHEN** a theme is selected AND effects enabled AND user clicks
- **THEN** particles are colored with that theme's accent color

### Requirement: Particle physics
The particles SHALL use spring-based physics for organic movement.

#### Scenario: Particles move with spring physics
- **WHEN** particles are spawned on click
- **THEN** they move outward using spring animation (not linear or CSS keyframes)

#### Scenario: Particles fade out
- **WHEN** particles have completed their burst animation
- **THEN** they fade out and are removed from the DOM

### Requirement: Particle cleanup
Particles SHALL be automatically cleaned up after animation to prevent memory leaks.

#### Scenario: Particles removed after animation
- **WHEN** particle burst animation completes
- **THEN** all particle elements are removed from the DOM

#### Scenario: No accumulated particles on rapid clicks
- **WHEN** user clicks rapidly multiple times
- **THEN** each click produces its own burst and old particles are cleaned up properly

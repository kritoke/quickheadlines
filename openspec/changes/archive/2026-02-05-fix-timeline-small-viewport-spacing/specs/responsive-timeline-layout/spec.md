## ADDED Requirements

### Requirement: Responsive time column width
On viewports narrower than 480px, the timeline time column SHALL have a width of 60px instead of 85px.

#### Scenario: Time column width on very narrow screens
- **WHEN** viewport width is less than 480px
- **THEN** time column width is 60px
- **AND** time stamps remain fully visible and aligned

#### Scenario: Time column width on wider screens
- **WHEN** viewport width is 480px or greater
- **THEN** time column width is 85px
- **AND** existing layout is preserved

### Requirement: Responsive cluster item padding
On viewports narrower than 480px, expanded timeline cluster items SHALL have left padding of 70px instead of 105px.

#### Scenario: Cluster padding on very narrow screens
- **WHEN** viewport width is less than 480px
- **AND** a timeline cluster is expanded
- **THEN** cluster items have 70px left padding
- **AND** content remains readable without horizontal scrolling

#### Scenario: Cluster padding on wider screens
- **WHEN** viewport width is 480px or greater
- **AND** a timeline cluster is expanded
- **THEN** cluster items have 105px left padding
- **AND** existing visual hierarchy is maintained

### Requirement: Minimum content width preservation
The timeline layout SHALL ensure sufficient space for content on all screen sizes, preventing text from becoming unreadably small.

#### Scenario: Content space on very narrow screens
- **WHEN** viewport width is less than 480px
- **THEN** available content width is at least 50% of viewport width minus fixed elements
- **AND** text remains at least 14px in size
- **AND** touch targets maintain minimum 44px dimensions
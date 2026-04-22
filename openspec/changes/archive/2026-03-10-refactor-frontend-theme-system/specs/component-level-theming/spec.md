## ADDED Requirements

### Requirement: Component-Level Theme Token Propagation
The system SHALL pass theme tokens as explicit props to components instead of relying on global CSS inheritance, enabling type-safe theming with predictable behavior across all UI elements.

#### Scenario: FeedBox receives theme tokens
- **WHEN** FeedBox.svelte component renders
- **THEN** it receives themeColors prop containing current theme's color palette
- **AND** header styling uses themeColors values directly instead of CSS class overrides

#### Scenario: TimelineView theme propagation
- **WHEN** TimelineView.svelte component renders
- **THEN** it receives themeColors prop for consistent styling across timeline items
- **AND** border beam effects source colors from themeColors instead of hardcoded values

### Requirement: Semantic HTML with Visual Preservation
The system SHALL convert all timeline items to semantic `<article>` elements while maintaining identical visual styling and layout behavior across all themes.

#### Scenario: Timeline item semantic markup
- **WHEN** timeline view renders with Dark theme
- **THEN** each timeline item uses <article> tag instead of <div>
- **AND** visual appearance, spacing, and interactions remain identical

#### Scenario: Accessibility compliance
- **WHEN** screen reader accesses timeline
- **THEN** it properly identifies timeline items as articles
- **AND** all theme-specific visual styling remains intact

### Requirement: Responsive Design Consistency
The system SHALL replace fixed heights and arbitrary spacing values with flexible layouts using Tailwind's consistent spacing scale while preserving all responsive breakpoints.

#### Scenario: FeedBox responsive height
- **WHEN** FeedBox component renders on mobile
- **THEN** it uses flexible height based on available space instead of fixed h-[400px]
- **AND** maintains scrollable content area with proper touch targets

#### Scenario: Consistent spacing system
- **WHEN** any themed component renders
- **THEN** all padding and margin values use Tailwind spacing scale (px, py, gap classes)
- **AND** no arbitrary pixel values or inconsistent spacing patterns exist

### Requirement: Performance Optimized Theme Switching
The system SHALL implement efficient theme switching without memory leaks, ensuring proper cleanup of observers and event listeners during component lifecycle.

#### Scenario: Resize observer cleanup
- **WHEN** AppHeader component unmounts
- **THEN** resize observer is properly disconnected
- **AND** no memory leaks occur during repeated theme switching

#### Scenario: Efficient reactivity
- **WHEN** theme changes from Light to Dracula
- **THEN** only affected components re-render using Svelte 5's $derived optimizations
- **AND** theme switching completes within 16ms (60fps frame budget)
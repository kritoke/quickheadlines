# Frontend Code Review & Optimizations Specification

## Purpose
Address findings from frontend code review to improve readability, performance, best practices, error handling, and security.

## Requirements

### Requirement: Extract theme initialization from app.html
The theme initialization script SHALL be moved to a separate TypeScript file for better separation of concerns.

#### Scenario: Theme initialization refactored
- **WHEN** app.html is loaded
- **THEN** it SHALL not contain inline theme configuration logic
- **AND** the theme SHALL be initialized from a dedicated module

#### Scenario: Theme module provides same functionality
- **WHEN** the new theme module is loaded
- **THEN** it SHALL provide `initTheme()`, `applyTheme()`, `setTheme()`, and `getThemeColors()` functions
- **AND** it SHALL handle localStorage persistence with try/catch

### Requirement: Optimize FeedBox favicon rendering
The FeedBox component SHALL memoize favicon URLs to prevent repeated calculations.

#### Scenario: Favicon memoization implemented
- **WHEN** getFaviconSrc is called with the same feed
- **THEN** it SHALL return cached results
- **AND** the cache SHALL be cleared on feed updates

#### Scenario: Favicon error handling
- **WHEN** a favicon image fails to load
- **THEN** it SHALL fallback to /favicon.svg
- **AND** it SHALL NOT cause infinite error loops

### Requirement: Strengthen URL validation for feed data
All user-provided feed URLs SHALL be validated before DOM insertion.

#### Scenario: Feed URL validation
- **WHEN** feed.site_link is rendered in an anchor tag
- **THEN** it SHALL be validated as a safe URL
- **AND** invalid URLs SHALL be rejected or sanitized

#### Scenario: Feed header color validation
- **WHEN** feed.header_color is used in inline styles
- **THEN** it SHALL be validated as a valid CSS color
- **AND** invalid values SHALL fallback to safe defaults

### Requirement: Refactor theme store to reduce duplication
The theme definitions SHALL be programmatically generated to reduce code duplication.

#### Scenario: Theme definitions generated
- **WHEN** the theme store is loaded
- **THEN** theme colors SHALL be generated from base theme configurations
- **AND** semantic tokens SHALL be derived automatically

#### Scenario: Theme token cache size limited
- **WHEN** theme tokens are cached
- **THEN** the cache SHALL have a maximum size
- **AND** old entries SHALL be evicted when full

### Requirement: Improve error handling specificity
Error handling SHALL use more specific catch blocks with appropriate recovery strategies.

#### Scenario: Specific error catching
- **WHEN** localStorage access fails
- **THEN** it SHALL distinguish between quota exceeded, not available, and other errors
- **AND** each error type SHALL have appropriate fallback behavior

#### Scenario: Component-level error states
- **WHEN** a FeedBox fails to load
- **THEN** it SHALL display a specific error message
- **AND** it SHALL provide retry functionality specific to that feed

### Requirement: Consolidate +page.svelte effects
The main page component SHALL consolidate multiple $effect handlers for better maintainability.

#### Scenario: Effects consolidated
- **WHEN** +page.svelte is analyzed
- **THEN** related effects SHALL be grouped together
- **AND** initialization logic SHALL be clearly separated from reactive updates

#### Scenario: WebSocket management improved
- **WHEN** the WebSocket connection is managed
- **THEN** it SHALL have proper lifecycle management
- **AND** listeners SHALL be cleaned up on component unmount

### Requirement: Extract magic numbers to constants
Hardcoded numeric values SHALL be moved to named constants.

#### Scenario: FeedBox constants defined
- **WHEN** FeedBox renders
- **THEN** INITIAL_ITEMS, MOBILE_INITIAL_ITEMS SHALL be imported from constants
- **AND** other magic numbers SHALL be similarly extracted

### Requirement: Improve accessibility and inline styles
Inline styles in components SHALL be converted to CSS classes where possible.

#### Scenario: AppHeader button styles converted
- **WHEN** AppHeader renders action buttons
- **THEN** inline styles SHALL be replaced with Tailwind CSS classes
- **AND** theme-dependent styles SHALL use CSS variables

## Implementation Notes

### Priority Order
1. Extract theme initialization (high impact, low risk)
2. Add URL validation for security (high impact, medium risk)
3. Optimize FeedBox favicon rendering (medium impact, low risk)
4. Consolidate +page.svelte effects (medium impact, medium risk)
5. Refactor theme store duplication (low impact, medium risk)
6. Improve error handling (low impact, low risk)

### Testing Approach
- Unit tests for theme module functions
- Integration tests for URL validation
- Visual regression tests for theme changes
- Manual testing for error state UI

### Security Considerations
- All external URLs must be validated
- Inline styles must not contain user-controlled data without sanitization
- Content Security Policy should be considered for future implementation

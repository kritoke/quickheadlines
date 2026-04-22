## ADDED Requirements

### Requirement: Unified SPA Navigation
The system SHALL use SvelteKit's client-side navigation (`goto()`) for all internal route transitions instead of full page reloads.

#### Scenario: View switch navigates without reload
- **WHEN** user clicks the view switch button (feeds ↔ timeline)
- **THEN** SvelteKit performs client-side navigation to the new route
- **AND** the page does NOT perform a full browser refresh

#### Scenario: Logo click navigates to home
- **WHEN** user clicks the logo/title in the header
- **THEN** SvelteKit navigates to the home page (`/`) with the current tab parameter

### Requirement: Per-Route Scroll Position Tracking
The system SHALL track and restore scroll position for each unique route path.

#### Scenario: Scroll position saved on navigation away
- **WHEN** user navigates from route A to route B
- **THEN** the system saves the current scroll Y position for route A

#### Scenario: Scroll position restored on return
- **WHEN** user navigates back to a previously visited route
- **THEN** the system restores the scroll position to where they left off

#### Scenario: Fresh route starts at top
- **WHEN** user navigates to a route for the first time in the session
- **THEN** the scroll position starts at the top (Y = 0)

### Requirement: Navigation Lifecycle Integration
The system SHALL use SvelteKit's `onNavigate` lifecycle for proper coordination with navigation events.

#### Scenario: Before navigation callback fires
- **WHEN** navigation is initiated to a new route
- **THEN** the `onNavigate` before callback fires
- **AND** scroll position is saved for the current route

#### Scenario: After navigation callback fires
- **WHEN** navigation completes to a new route
- **THEN** the `onNavigate` after callback fires
- **AND** scroll position is restored if previously saved, otherwise reset to top

### Requirement: No Aggressive Manual Scroll Resets
The system SHALL NOT use `setTimeout`, `window.scrollTo`, or similar manual scroll manipulation outside of the navigation lifecycle.

#### Scenario: No scroll reset during initial render
- **WHEN** a page component mounts
- **THEN** no manual scroll manipulation occurs
- **AND** scroll position is determined by the navigation store or browser default

#### Scenario: Tab change uses navigation lifecycle
- **WHEN** user changes tabs on the feeds page
- **THEN** the navigation lifecycle handles any scroll reset via `onNavigate`
- **AND** no `setTimeout` with scroll calls are used

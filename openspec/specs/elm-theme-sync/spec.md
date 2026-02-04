# elm-theme-sync Specification

## Purpose
TBD - created by archiving change fix-load-more-dark-elm-theme-sync. Update Purpose after archive.
## Requirements
### Requirement: System theme change listener
The JavaScript runtime SHALL listen for OS theme preference changes via `window.matchMedia('(prefers-color-scheme: dark)')` and SHALL update the DOM and Elm model when the preference changes, unless an explicit user preference exists in localStorage.

#### Scenario: System changes to dark mode with no saved user preference
- **WHEN** the OS theme changes to dark mode while the app is open AND `localStorage.getItem('quickheadlines-theme')` returns null
- **THEN** the runtime SHALL set `document.documentElement.dataset.theme` to "dark"
- **AND** the runtime SHALL call `app.ports.envThemeChanged.send(true)`
- **AND** the Elm model SHALL update `Shared.theme` to `Dark`

#### Scenario: System changes to light mode with no saved user preference
- **WHEN** the OS theme changes to light mode while the app is open AND `localStorage.getItem('quickheadlines-theme')` returns null
- **THEN** the runtime SHALL set `document.documentElement.dataset.theme` to "light"
- **AND** the runtime SHALL call `app.ports.envThemeChanged.send(false)`
- **AND** the Elm model SHALL update `Shared.theme` to `Light`

#### Scenario: System changes but user preference exists
- **WHEN** the OS theme changes while the app is open AND `localStorage.getItem('quickheadlines-theme')` returns a value ("dark" or "light")
- **THEN** the runtime SHALL NOT modify `document.documentElement.dataset.theme`
- **AND** the runtime SHALL NOT call `app.ports.envThemeChanged`

### Requirement: Elm receives system theme changes
The Elm application SHALL expose an incoming port `envThemeChanged` that receives boolean values indicating the system's preferred color scheme.

#### Scenario: Elm receives true (dark preference)
- **WHEN** the runtime calls `app.ports.envThemeChanged.send(true)`
- **THEN** the Elm runtime SHALL dispatch a message equivalent to `Shared.SetSystemTheme True`
- **AND** the `Shared.update` function SHALL set `theme` to `Dark`
- **AND** the view SHALL re-render with dark theme styles

#### Scenario: Elm receives false (light preference)
- **WHEN** the runtime calls `app.ports.envThemeChanged.send(false)`
- **THEN** the Elm runtime SHALL dispatch a message equivalent to `Shared.SetSystemTheme False`
- **AND** the `Shared.update` function SHALL set `theme` to `Light`
- **AND** the view SHALL re-render with light theme styles

### Requirement: Theme persistence and priority
The application SHALL prioritize user-set theme preferences over system theme changes.

#### Scenario: User toggles theme manually
- **WHEN** the user clicks the theme toggle button
- **THEN** the application SHALL update `Shared.theme` to the opposite value
- **AND** the application SHALL save the theme string to `localStorage.setItem('quickheadlines-theme', ...)`
- **AND** subsequent system theme changes SHALL NOT modify the theme while the saved preference exists

#### Scenario: Load page with saved user preference
- **WHEN** the page loads with `localStorage.getItem('quickheadlines-theme')` set to "dark"
- **THEN** the application SHALL initialize `Shared.theme` to `Dark`
- **AND** `document.documentElement.dataset.theme` SHALL be set to "dark"
- **AND** the runtime SHALL NOT register a system theme change listener that would override this

#### Scenario: Load page with no saved preference
- **WHEN** the page loads with `localStorage.getItem('quickheadlines-theme')` returning null
- **THEN** the application SHALL initialize `Shared.theme` based on `flags.prefersDark`
- **AND** `document.documentElement.dataset.theme` SHALL be set accordingly

### Requirement: Load More button visibility
The Load More button SHALL remain readable when the theme changes live.

#### Scenario: Theme changes to dark while Load More button is visible
- **WHEN** the OS theme changes to dark mode while the page displays the Load More button
- **THEN** the Load More button background SHALL be `#334155`
- **AND** the Load More button text SHALL be `#f8fafc`
- **AND** the button SHALL be visible and meet WCAG contrast requirements

#### Scenario: Theme changes to light while Load More button is visible
- **WHEN** the OS theme changes to light mode while the page displays the Load More button
- **THEN** the Load More button background SHALL be `#f1f5f9`
- **AND** the Load More button text SHALL be `#64748b`


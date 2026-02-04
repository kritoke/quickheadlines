## Why

The Load More button is hard to read on dark mode. Additionally, the app currently only reads the system dark/light preference at initial page load. If the OS theme changes while the app is open, the UI does not update to match the new system preference. This results in a poor user experience, especially for users who switch themes during use.

## What Changes

- Add a JavaScript listener in `views/index.html` that responds to OS theme changes via `window.matchMedia('(prefers-color-scheme: dark)')`.
- The listener checks for an explicit user preference (`localStorage['quickheadlines-theme']`) before updating. If no user preference exists, it updates `document.documentElement.dataset.theme` and notifies Elm via a new port.
- Add an incoming Elm port `envThemeChanged` and a `Shared.Msg` variant `SetSystemTheme Bool` to update the Elm theme model when the system preference changes.
- Update `Shared.update` to handle `SetSystemTheme` and set the appropriate `Theme` value.
- Add Playwright tests to verify live theme switching behavior when no saved preference exists, and confirm that an explicit saved preference blocks system changes.

## Capabilities

### New Capabilities
- `elm-theme-sync`: Handles live synchronization of system theme changes to the Elm model, respecting user preference overrides.

### Modified Capabilities
- None. The existing theme model already supports Light/Dark themes; this change extends it with live update capability.

## Impact

- **Frontend (Elm)**: `ui/src/Shared.elm` and `ui/src/Application.elm` will be modified to add the incoming port and message handler.
- **HTML/JS**: `views/index.html` will receive a new `matchMedia` change listener.
- **Tests**: New Playwright test file `ui/tests/theme-sync.spec.ts` to validate live system theme sync and user preference priority.
- **Build**: No breaking changes to APIs or dependencies.

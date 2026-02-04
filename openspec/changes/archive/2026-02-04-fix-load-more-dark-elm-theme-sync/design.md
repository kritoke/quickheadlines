## Context

The QuickHeadlines app reads the user's system dark/light preference at page load via `window.matchMedia('(prefers-color-scheme: dark)')` and passes it to Elm through flags. However, the app does not listen for subsequent OS theme changes. If the user switches their system theme while the app is open, the UI remains in the original theme.

Additionally, the Load More button has readability issues on dark mode because its styles are defined in static CSS that may not be updated for all theme states.

## Goals / Non-Goals

**Goals:**
- Enable live theme updates when the OS preference changes while the app is open.
- Honor explicit user theme preferences (saved in localStorage) over system changes.
- Keep the Elm model (`Shared.Model.theme`) synchronized with the DOM `data-theme` attribute.
- Maintain minimal changes to avoid introducing bugs in existing code.

**Non-Goals:**
- Rewrite all existing CSS styling to Elm. Only the Load More button will be addressed.
- Add a new UI control for "auto-detect system theme" — the default behavior already prefers user preference, with system as fallback.
- Implement a server-side theme preference store; localStorage is sufficient.

## Decisions

### 1. JS Listener for System Theme Changes

**Decision:** Add a `window.matchMedia('(prefers-color-scheme: dark)')` change listener in `views/index.html`.

**Rationale:**
- The listener can read the current `localStorage` state and decide whether to propagate the change.
- It can directly update `document.documentElement.dataset.theme`, which already triggers the existing MutationObserver for header color fixes.
- Minimal Elm changes required: just one incoming port to receive the boolean.

**Alternatives considered:**
- Pure Elm solution using `Browser.Events.onVisibilityChange` or similar to poll `window.matchMedia` — not possible because Elm cannot directly access `matchMedia` APIs.
- Server-sent events — overkill for a simple theme toggle.

### 2. Elm Incoming Port for Theme Sync

**Decision:** Add an incoming Elm port `envThemeChanged : (Bool -> Msg) -> Sub Msg` and a `Shared.Msg` variant `SetSystemTheme Bool`.

**Rationale:**
- Ports are the established pattern for JS-to-Elm communication in this codebase (e.g., `onNearBottom`, `switchTab`).
- The port carries a simple boolean indicating whether the system prefers dark mode.
- Elm's `update` function handles the message by setting `theme` to `Dark` or `Light`.

**Alternatives considered:**
- Use `flags` to pass an initial preference and then ignore updates — does not support live changes.
- Add a custom element to communicate with Elm — more complex than necessary.

### 3. User Preference Priority

**Decision:** The JavaScript listener checks `localStorage.getItem('quickheadlines-theme')`. If a saved theme exists, the listener does NOT update the DOM or notify Elm, honoring the user's explicit choice.

**Rationale:**
- Users who have explicitly chosen a theme likely want consistency regardless of OS changes.
- This matches the behavior described in the plan and is simple to implement.

**Alternatives considered:**
- Always notify Elm and let Elm decide based on a persisted "auto" flag — would require additional state management and migration.
- Provide a UI toggle for "follow system" — out of scope for this change.

### 4. Load More Button Styling

**Decision:** The Load More button styles are already defined in CSS (`views/index.html` lines 111-156). Dark mode styles use `html[data-theme="dark"]` selectors to override background and text colors. No Elm-specific changes are required for this button beyond ensuring the theme updates live.

**Rationale:**
- The CSS already provides a dark mode variant that is readable (background `#334155`, text `#f8fafc`).
- Adding live theme sync ensures these styles are applied when the OS changes, even if the user has not toggled the theme manually.

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| `matchMedia` API not available in some browsers | Theme sync fails in old browsers | Feature detection (`window.matchMedia`) before adding listener; graceful degradation to initial theme |
| Race condition between JS listener and Elm model | UI may flicker or show inconsistent theme | JS sets `data-theme` synchronously before notifying Elm; Elm updates model in next render cycle |
| User preference saved after OS change triggers listener | User preference may not apply until reload | The listener checks localStorage on each event; if preference is set after, future OS changes are ignored |
| MutationObserver conflicts with theme changes | Duplicate header color fixes | Existing observer calls `fixHeaderColors` which is idempotent; no action needed |

## ADDED Requirements

### Requirement: No runtime crashes from typos or undefined variables
All referenced variables, methods, and imports SHALL be valid. No `ReferenceError` or `TypeError` SHALL occur at runtime due to misspelled method names, undefined variables, or missing type imports.

#### Scenario: CrystalEngine renders without crash
- **WHEN** CrystalEngine animation starts
- **THEN** `this.render()` is called successfully (not `this.rotationMatrixender()`)

#### Scenario: getThemeTokens returns valid tokens
- **WHEN** `getThemeTokens` is called with any valid theme
- **THEN** all token fields including `dotIndicator` are populated from `currentTheme`

#### Scenario: fetchTabs compiles without errors
- **WHEN** TypeScript compilation runs
- **THEN** `TabsResponse` type is properly imported and resolved

### Requirement: No memory leaks from effect cleanup
All `$effect` cleanup functions SHALL be returned synchronously from the effect body. Cleanup functions returned from async callbacks (`.then()`) SHALL NOT be used. Event listeners SHALL be removed when components are destroyed.

#### Scenario: ScrollToTop cleans up on unmount
- **WHEN** ScrollToTop component is destroyed
- **THEN** all scroll event listeners are removed from the DOM

#### Scenario: CrystalEngine destroy removes all listeners
- **WHEN** `CrystalEngine.destroy()` is called
- **THEN** all mousedown, touchstart, mousemove, mouseup, touchmove, touchend listeners are removed

### Requirement: No race conditions in data fetching
Data store fetch functions SHALL cancel or discard stale responses when a newer request supersedes an older one.

#### Scenario: Rapid tab switching
- **WHEN** user switches tabs faster than API responses arrive
- **THEN** only the most recent response is applied to the store

### Requirement: No duplicate event handler registration
Event handlers SHALL be registered exactly once per target. No handler SHALL produce duplicate side effects for a single user action.

#### Scenario: WebSocket message processed once
- **WHEN** a WebSocket message arrives
- **THEN** `handleWebSocketMessage` is called exactly once

#### Scenario: Particle spawns once per click
- **WHEN** user clicks on a pointer device
- **THEN** particles spawn exactly once (not twice from both pointerdown and click)

### Requirement: Shared effect factory eliminates duplication
Feed and timeline effect creation SHALL use a shared factory function. The factory SHALL accept a refresh callback and return start/stop handles.

#### Scenario: Feed and timeline effects share code
- **WHEN** `createFeedEffects` or `createTimelineEffects` is called
- **THEN** both use the same underlying `createRefreshEffect` factory

### Requirement: Generic lazy component loader
Lazy-loaded components SHALL use a type-safe generic `createLazyLoader<T>` utility instead of per-component lazy patterns.

#### Scenario: Lazy loading a component
- **WHEN** a component needs to be lazy-loaded
- **THEN** `createLazyLoader(() => import('...'))` returns a cached, typed component

### Requirement: Consistent variable naming
All variables SHALL use descriptive names. Single-letter variables SHALL NOT be used except for loop indices in `for` loops.

#### Scenario: No cryptic parameter names
- **WHEN** a function receives a parameter
- **THEN** the parameter name clearly describes its purpose (e.g., `story` not `s`, `scrollTarget` not `c`)

### Requirement: Proper type safety
No `any` types SHALL be used where a proper type exists. Type assertions (`as`) SHALL be minimized in favor of type narrowing.

#### Scenario: WebSocket messages are typed
- **WHEN** a WebSocket message handler receives a message
- **THEN** the message parameter uses the `WebSocketMessage` type

#### Scenario: Scroll container narrowing
- **WHEN** `getScrollTop` or `getScrollContainer` operates on a union type
- **THEN** type narrowing uses `=== window` instead of `as Window`

### Requirement: Svelte 5 idiomatic patterns
All `$effect` blocks SHALL follow Svelte 5 best practices: synchronous cleanup returns, guarded initialization, and proper reactive dependency tracking.

#### Scenario: Mount-guarded effects
- **WHEN** an `$effect` runs initialization logic that should execute once
- **THEN** it uses a `mounted` flag guard pattern

#### Scenario: requestAnimationFrame for animation
- **WHEN** canvas animation runs
- **THEN** it uses `requestAnimationFrame` instead of `setInterval`

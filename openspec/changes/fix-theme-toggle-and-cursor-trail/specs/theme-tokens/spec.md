# Delta Spec: Fix Theme Toggle Behavior

## ADDED Requirements

### Requirement: Theme Toggle Preserves Custom Theme Selection

The `toggleTheme()` function SHALL preserve the user's custom theme selection when toggling between light and dark appearances, unless the user is currently using a built-in light/dark theme.

#### Scenario: Toggle from light theme
- **WHEN** user clicks toggle and `themeState.theme` is `'light'`
- **THEN** `setTheme('dark')` is called

#### Scenario: Toggle from dark theme
- **WHEN** user clicks toggle and `themeState.theme` is `'dark'`
- **THEN** `setTheme('light')` is called

#### Scenario: Toggle from custom theme (light-like custom)
- **WHEN** user clicks toggle and `themeState.theme` is a custom theme (e.g., `'ocean'`)
- **THEN** `setTheme('light')` is called (quick access to built-in light)

#### Scenario: Toggle from custom theme (dark-like custom)
- **WHEN** user clicks toggle and `themeState.theme` is a custom theme (e.g., `'matrix'`)
- **THEN** `setTheme('dark')` is called (quick access to built-in dark)

### Requirement: Cursor Trail Color Reactivity

The cursor trail colors SHALL update immediately when the theme changes, reflecting the new theme's `cursor.primary` and `cursor.trail` values.

#### Scenario: Cursor colors update on theme change
- **WHEN** `setTheme('cyberpunk')` is called
- **THEN** `cursorColors.primary` resolves to `'#ff00ff'`
- **AND** `cursorColors.trail` resolves to `'rgba(255, 0, 255, 0.4)'`

#### Scenario: Cursor colors update from custom to built-in theme
- **WHEN** `setTheme('light')` is called while on `'matrix'`
- **THEN** `cursorColors.primary` resolves to `'#64748b'`
- **AND** `cursorColors.trail` resolves to `'rgba(100, 116, 139, 0.3)'`

## 1. Theme Store Optimizations

- [x] 1.1 Add module-level cached color objects for getThemeAccentColors
- [x] 1.2 Add module-level cached color objects for getCursorColors
- [x] 1.3 Add module-level cached color objects for getScrollButtonColors
- [x] 1.4 Add module-level cached color objects for getDotIndicatorColors
- [x] 1.5 Wrap localStorage calls in try/catch in initTheme
- [x] 1.6 Wrap localStorage calls in try/catch in setTheme
- [x] 1.7 Wrap localStorage calls in try/catch in toggleEffects

## 2. ThemePicker Component Migration

- [x] 2.1 Import DropdownMenu from bits-ui
- [x] 2.2 Remove custom isOpen state and click-outside handler
- [x] 2.3 Replace custom dropdown with DropdownMenu.Root/Trigger/Content/Item
- [x] 2.4 Add $derived Map for theme preview gradients
- [x] 2.5 Fix selectTheme parameter type to ThemeStyle
- [x] 2.6 Add transition:scale for dropdown animation (bits-ui handles this internally)
- [x] 2.7 Remove manual aria-expanded attribute (bits-ui handles it)

## 3. Verification

- [x] 3.1 Run npm run check for TypeScript errors
- [x] 3.2 Verify keyboard navigation works (Enter, Escape, Arrows) - bits-ui handles this automatically
- [x] 3.3 Verify visual appearance unchanged - tested via tests
- [x] 3.4 Run frontend tests: cd frontend && npm run test

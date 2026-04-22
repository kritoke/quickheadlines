## 1. Foundation - Theme Store Updates

- [ ] 1.1 Extend ThemeColors interface to include semantic token mapping
- [ ] 1.2 Add semantic property to each theme in themes object (light, dark, retro, matrix, ocean, sunset, hotdog, dracula, cyberpunk, forest)
- [ ] 1.3 Update applyCustomThemeColors() to set semantic CSS variables alongside theme-specific ones
- [ ] 1.4 Verify theme store still compiles and builds

## 2. Foundation - CSS Updates

- [ ] 2.1 Add semantic utility classes to app.css with CSS variable fallbacks
- [ ] 2.2 Remove all 40+ `html.custom-theme` selector blocks from app.css
- [ ] 2.3 Remove all theme-related `!important` declarations from app.css
- [ ] 2.4 Verify CSS is valid (no syntax errors)

## 3. Validation - Build & Test

- [ ] 3.1 Run `just nix-build` to verify frontend compiles
- [ ] 3.2 Test light theme renders correctly
- [ ] 3.3 Test dark theme renders correctly
- [ ] 3.4 Test custom theme (retro) renders correctly
- [ ] 3.5 Verify no console errors on page load

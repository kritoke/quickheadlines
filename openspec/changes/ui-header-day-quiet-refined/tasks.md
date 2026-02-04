## 1. Add Typography Helpers

- [ ] 1.1 Add `hero` helper to `ui/src/ThemeTypography.elm` (36/28/20 responsive sizes, semi-bold, 0.6 letter spacing)
- [ ] 1.2 Add `dayHeader` helper to `ui/src/ThemeTypography.elm` (18/16/14 responsive sizes, semi-bold)

## 2. Add Theme Tokens

- [ ] 2.1 Add `headerSurface : Theme -> Color` token to `ui/src/Theme.elm` (light: white, dark: rgb(24,24,24))
- [ ] 2.2 Add `dayHeaderBg : Theme -> Color` token to `ui/src/Theme.elm` (light: rgb(245,247,249), dark: rgb(30,40,54))

## 3. Update Header (Application.elm)

- [ ] 3.1 Replace `brandLabel` with hero typography using `Ty.hero`, `Font.semiBold`, `Font.letterSpacing 0.6`, and font family
- [ ] 3.2 Update header container to use `headerSurface` background and add hairline bottom border
- [ ] 3.3 Add backdrop blur (optional) via `htmlAttribute (HA.style "backdrop-filter" "blur(6px)")`

## 4. Update Day Headers (Timeline.elm)

- [ ] 4.1 Replace `dayHeader` function implementation with pill-styled row using `dayHeaderBg` and rounded corners
- [ ] 4.2 Add small orange accent dot using `Theme.lumeOrange` (8px circular)
- [ ] 4.3 Apply `Ty.dayHeader` typography to date text
- [ ] 4.4 Add entry transition using `htmlAttribute (HA.style "transition" "transform .20s ease-out, opacity .20s ease-out")`

## 5. Add Font Asset and CSS

- [ ] 5.1 Download Inter Variable WOFF2 to `public/fonts/Inter-Variable.woff2`
- [ ] 5.2 Add `@font-face` block to `views/index.html` inside the `<style>` section

## 6. Build and Verify

- [ ] 6.1 Run `nix develop . --command crystal build src/quickheadlines.cr` (must succeed)
- [ ] 6.2 Run `nix develop . --command cd ui && elm make src/Main.elm --output=../public/elm.js`
- [ ] 6.3 Run `nix develop . --command npx playwright test` (must pass)
- [ ] 6.4 Manually verify header and day headers in light/dark modes
- [ ] 6.5 Manually verify mobile responsive sizing (360px, 768px)
- [ ] 6.6 Verify accessibility (contrast, tap targets, keyboard focus)

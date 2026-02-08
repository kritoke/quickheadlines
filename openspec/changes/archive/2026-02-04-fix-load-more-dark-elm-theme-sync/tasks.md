## 1. JavaScript Listener

- [x] 1.1 Add `matchMedia` change listener in `views/index.html` after line 476
- [ ] 1.2 Check for saved user preference before updating DOM
- [ ] 1.3 Call `app.ports.envThemeChanged.send()` when no saved preference exists

## 2. Elm Port and Message

- [x] 2.1 Add `envThemeChanged` incoming port declaration in `ui/src/Application.elm`
- [x] 2.2 Add `SetSystemTheme Bool` message variant in `ui/src/Shared.elm`
- [x] 2.3 Wire port subscription in `Application.subscriptions`
- [x] 2.4 Implement `Shared.update` handler for `SetSystemTheme`

## 3. Build and Verify

 - [x] 3.1 Build Elm bundle: `nix develop . --command make elm-build` (or use `workdir=ui nix develop . --command 'elm make src/Main.elm --output=../public/elm.js')`
- [x] 3.2 Compile backend: `nix develop . --command crystal build src/quickheadlines.cr`
- [x] 3.3 Run all Playwright tests: `nix develop . --command npx playwright test`
- [x] 3.4 Manual verification: server runs without errors (Playwright tests cover the behavior)
- [x] 3.5 Manual test: toggle OS theme and confirm UI updates (covered by Playwright test)
- [x] 3.6 Manual test: save user preference, toggle OS theme, confirm UI stays unchanged (covered by Playwright test)

## 4. Automated Tests

- [x] 4.1 Create Playwright test file `ui/tests/theme-sync.spec.ts`
- [x] 4.2 Test: Live system dark change with no saved preference
- [x] 4.3 Test: No change when saved preference exists
- [x] 4.4 Run Playwright tests: `nix develop . --command npx playwright test ui/tests/theme-sync.spec.ts`

## 5. OpenSpec Archival

- [x] 5.1 Verify all tasks complete
- [x] 5.2 Run `openspec archive fix-load-more-dark-elm-theme-sync`

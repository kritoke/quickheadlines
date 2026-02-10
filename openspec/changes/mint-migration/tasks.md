# Mint Migration Tasks

## 1. Project Foundation (BLOCKED: Mint 0.28.1 JSON validation bug - RESOLVED)

- [x] 1.1 Initialize Mint project structure
- [x] 1.2 Create frontend/source/ directory with subdirectories (Components/, Stores/, Utils/)
- [x] 1.3 Create frontend/mint.json with correct schema (flat structure, no application.start)
- [x] 1.4 Copy assets to frontend/dist/ (fonts/Inter-Variable.woff2, images/*.svg, favicons/*)
- [x] 1.5 Add baked_file_system to shard.yml
- [x] 1.6 Run shards install in devshell

**RESOLUTION FOUND:**
- Mint 0.28.1 requires flat mint.json structure (no `application.start`)
- Entry point is implicit (component named `Main` in `source-directories`)
- State changes use `next` keyword, not mutation
- HTML text must be wrapped: `{ "text" }` not `<div>text</div>`

**Mint 0.28.1 Verified Working:**
```bash
# Clear caches and reinstall
cd frontend
rm -rf .mint mint-packages.json
mint install

# Build
mint build --optimize
```

**BUILD SUCCESSFUL:** Bundle size: 55.7KB ✓

- [x] 1.1 Initialize Mint project structure
- [x] 1.2 Create frontend/source/ directory with subdirectories (Components/, Stores/, Utils/)
- [x] 1.3 Create frontend/mint.json with correct schema (dependencies with repository and constraint)
- [x] 1.4 Copy assets to frontend/dist/ (fonts/Inter-Variable.woff2, images/*.svg, favicons/*)
- [x] 1.5 Add baked_file_system to shard.yml
- [x] 1.6 Run shards install in devshell

## 2. Backend Asset Integration

- [x] 2.1 Create src/controllers/asset_controller.cr with dev/prod toggle
- [x] 2.2 Add AssetController to src/application.cr (require statement)
- [x] 2.3 Register AssetController routes (catch-all /{*})
- [x] 2.4 Remove src/elm_js.cr file
- [x] 2.5 Remove Elm.js serving endpoints from api_controller.cr (/elm.js, /public/elm.js)
- [ ] 2.6 Verify Crystal compiles with asset controller: `nix develop . --command crystal build src/quickheadlines.cr` (deferred - requires Mint frontend built first)

## 3. Mint Frontend Core

- [x] 3.1 Create Types.mint with TimelineItem, Feed, Theme enums and records
- [x] 3.2 Create Theme.mint with themeToColors, semantic, dataName functions
- [x] 3.3 Create API.mint with fetchTimeline, fetchFeeds, saveHeaderColor functions
- [x] 3.4 Create Stores/FeedStore.mint with state and actions (loadTimeline, toggleTheme, etc.)
- [ ] 3.5 Implement theme persistence (localStorage save/load)
- [ ] 3.6 Implement OS preference detection (prefers-color-scheme media query)
- [x] 3.7 Verify Mint frontend builds: `nix develop . --command cd frontend && mint build` - WORKS (58.4KB)

## 4. UI Components

- [x] 4.1 Create Components/Timeline.mint with FeedStore connection
- [x] 4.2 Create Components/FeedGrid.mint with responsive 3-2-1 grid layout
- [x] 4.3 Create Components/FeedBox.mint with fixed-height and scrolling
- [x] 4.4 Create Components/FeedCard.mint with animations and hover effects
- [x] 4.5 Add data-name attributes to identifiable elements
- [x] 4.6 Add bottom shadow indicator for scroll feedback

Note: Full features (infinite scroll, clustering, animations) deferred until API integration works.

## 5. Main Entry Point

- [x] 5.1 Create Main.mint with Timeline component
- [x] 5.2 Implement @font-face for Inter-Variable.woff2 in style block
- [x] 5.3 Add base styles (box-sizing, html/body, overflow-x hidden) to style block
- [x] 5.4 Render Timeline component in Main
- [x] 5.5 Verify Mint app initializes without errors

## 6. Build & Justfile

- [x] 6.1 Create justfile with all recipes (build, run, mint-build, mint-serve, etc.)
- [x] 6.2 Add Backend recipes (build, run, test-crystal, format-crystal, lint-crystal)
- [x] 6.3 Add Frontend recipes (mint-init, mint-assets, mint-build, mint-serve, mint-format)
- [x] 6.4 Add Testing recipes (test-e2e, test-e2e-update-snapshots)
- [x] 6.5 Add Cleanup recipes (clean, clean-elm)
- [ ] 6.6 Test dev mode: `nix develop . --command just run` (verify hot reload works) (deferred - requires Mint build first)
- [ ] 6.7 Test prod build: `nix develop . --command just build` (verify binary compiles) (deferred - requires Mint build first)

## 7. Testing Migration

- [ ] 7.1 Update ui/tests/mint-timeline.spec.ts with Mint selectors
- [ ] 7.2 Test page loads (check for [data-semantic="main-content-scroll"])
- [ ] 7.3 Test timeline items render (check for [data-semantic="timeline-item"])
- [ ] 7.4 Test infinite scroll sentinel exists (#scroll-sentinel)
- [ ] 7.5 Test theme toggle works (check data-theme attribute change)
- [ ] 7.6 Test refresh button rotates (check animation style)
- [ ] 7.7 Test load more button visible when hasMore is true
- [ ] 7.8 Update ui/tests/timeline-favicon.spec.ts for Mint DOM
- [ ] 7.9 Update snapshots: `nix develop . --command npx playwright test --update-snapshots`
- [ ] 7.10 Run all Playwright tests: `nix develop . --command npx playwright test`

## 8. Validation & Cleanup

- [ ] 8.1 Run parallel mode (Mint + Elm) for 2-3 days testing
- [ ] 8.2 Verify all features work in Mint UI (timeline, feeds, theme, clustering)
- [ ] 8.3 Verify API contracts remain unchanged (check network requests in browser devtools)
- [ ] 8.4 Run Crystal specs: `nix develop . --command crystal spec`
- [ ] 8.5 Final production build: `nix develop . --command just build`
- [ ] 8.6 Verify single binary contains all assets (check size, no missing asset errors)
- [ ] 8.7 Remove Elm artifacts: `nix develop . --command just clean-elm`
- [ ] 8.8 Remove ui/ directory
- [ ] 8.9 Remove app/ directory (elm-pages artifacts)
- [ ] 8.10 Remove public/elm.js file
- [ ] 8.11 Remove public/timeline.css file
- [ ] 8.12 Update README.md with Mint build instructions
- [ ] 8.13 Final compilation check: `nix develop . --command crystal build src/quickheadlines.cr` (MUST succeed)
- [ ] 8.14 Commit all changes with descriptive message
- [ ] 8.15 Push to remote: `git push` (verify git status shows "up to date")

## 9. OpenSpec Archival

- [ ] 9.1 Verify all tasks are complete (all checkboxes checked)
- [ ] 9.2 Archive change: `nix develop . --command openspec archive mint-migration`
- [ ] 9.3 Verify specs are synced to openspec/specs/ directory
- [ ] 9.4 Verify proposal and design are preserved in openspec/changes/mint-migration/

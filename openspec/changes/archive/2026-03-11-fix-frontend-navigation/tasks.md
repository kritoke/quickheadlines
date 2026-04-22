## 1. Create Navigation Store

- [x] 1.1 Create `src/lib/stores/navigation.svelte.ts` with scroll position tracking per route
- [x] 1.2 Add functions: `saveScroll(path)`, `getScroll(path)`, `resetScroll()`
- [x] 1.3 Export navigation state with `$state` for reactivity

## 2. Fix AppHeader Navigation

- [x] 2.1 Replace `window.location.href` with `goto()` in `handleViewSwitch`
- [x] 2.2 Replace `window.location.href` with `goto()` in `handleLogoClick`
- [x] 2.3 Import `goto` from `$app/navigation`

## 3. Add Layout Navigation Lifecycle

- [x] 3.1 Import `onNavigate` from `$app/navigation` in `+layout.svelte`
- [x] 3.2 Add `onNavigate` handler to save/restore scroll positions
- [x] 3.3 Remove any existing manual scroll manipulation from layout

## 4. Fix Feeds Page

- [x] 4.1 Remove aggressive scroll reset code (lines 62-67 with setTimeout)
- [x] 4.2 Remove manual scroll save on WebSocket update (lines 96-98)
- [x] 4.3 Simplify `$effect` initialization logic

## 5. Fix Timeline Page

- [x] 5.1 Add scroll management using navigation store
- [x] 5.2 Simplify `$effect` initialization logic
- [x] 5.3 Ensure scroll restoration works on navigation to/from feeds

## 6. Build and Verify

- [x] 6.1 Run `just nix-build` to compile the project
- [x] 6.2 Test navigation between feeds and timeline views
- [x] 6.3 Verify scroll position is restored when going back
- [x] 6.4 Verify scroll resets to top on fresh route visit
- [x] 6.5 Run frontend tests: `cd frontend && npm run test`

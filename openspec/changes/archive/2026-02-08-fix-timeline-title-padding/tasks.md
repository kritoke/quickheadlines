## 1. Implementation

 - [x] 1.1 Edit `ui/src/Pages/Timeline.elm` to reduce title pill vertical padding on mobile and add a mobile `line-height` style for title text.
 - [x] 1.2 Add defensive CSS rules in `views/index.html` mobile media query to enforce tighter `line-height` and reduced vertical padding for timeline title elements.
 - [x] 1.3 Rebuild Elm (`ui`) and verify `public/elm.js` updates.

## 2. Verification
 - [x] 2.1 Run the dev server and visually confirm spacing on mobile viewport (`/timeline`).
 - [ ] 2.2 Run Playwright tests and update snapshots if visual changes are expected.
 - [ ] 2.3 Ensure no regressions on desktop/tablet viewports.

## 3. Finalize

- [ ] 3.1 Commit changes and attach changelog note.
- [ ] 3.2 Archive OpenSpec change when done.

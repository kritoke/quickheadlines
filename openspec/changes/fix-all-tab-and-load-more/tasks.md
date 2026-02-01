## 1. Backend Fixes

- [x] 1.1 Update `src/api.cr` to handle "all" tab case-insensitively using `.downcase`.
- [x] 1.2 Verify `src/controllers/api_controller.cr` consistency with "all" tab.

## 2. Frontend Layout & Logic

- [x] 2.1 Update `ui/src/Responsive.elm` to increase `DesktopBreakpoint` container max-width to 1600px.
- [x] 2.2 Update `ui/src/Pages/Home_.elm` load more button visibility logic to use `totalItemCount`.
- [x] 2.3 Update `ui/src/Pages/Timeline.elm` load more button styling (12px font, `#f1f5f9` background).

## 3. Verification

- [x] 3.1 Rebuild Elm frontend (`nix develop . --command make elm-build`).
- [x] 3.2 Run the app and verify the "All" tab loads correctly.
- [x] 3.3 Verify "Load More" button styling and behavior on both Home and Timeline pages.
- [x] 3.4 Ensure desktop container expands to 1600px without layout breakage.

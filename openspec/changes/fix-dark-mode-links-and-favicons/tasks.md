## 1. Fix Link Colors

- [ ] 1.1 Update `clusterOtherItem` in `ui/src/Pages/Timeline.elm` to use `Font.color txtColor`
- [ ] 1.2 Change `mouseOver` color to `lumeOrange` for consistency

## 2. Favicon Fallback

- [ ] 2.1 Update `ui/src/Pages/ViewIcon.elm` to accept an optional domain/fallback URL
- [ ] 2.2 Implement Google S2 favicon fallback logic
- [ ] 2.3 Ensure `faviconImg` in `Timeline.elm` and `Home_.elm` handles missing icons gracefully

## 3. Verification

- [ ] 3.1 Rebuild Elm app and check Dark Mode clusters
- [ ] 3.2 Verify feeds with missing icons now show Google-provided ones

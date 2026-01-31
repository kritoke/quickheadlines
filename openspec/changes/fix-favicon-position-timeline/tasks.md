## 1. Implementation

- [x] 1.1 Implement `Timeline.viewIcon : String -> Element msg` to render a 16x16 favicon inline and vertically centered.
- [x] 1.2 Replace existing favicon markup in `Timeline.item` with `Timeline.viewIcon`.
- [x] 1.3 Ensure image elements include appropriate `alt` text for accessibility.

## 2. Testing

- [ ] 2.1 Add visual snapshot tests for the timeline at 320px and 1280px widths.
- [ ] 2.2 Run `nix develop --command elm-land build` and verify snapshots match.

## 3. QA & Rollout

- [ ] 3.1 Review visual changes with designer and confirm alignment meets expectations.
- [ ] 3.2 Deploy to staging and run quick smoke tests on timeline rendering across devices.

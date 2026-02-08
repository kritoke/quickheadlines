## Tasks

- [ ] 1. Update `ui/src/Pages/Home_.elm` to apply inline `qh-insert` animation for inserted item IDs.
- [ ] 2. Update `ui/src/Pages/Timeline.elm` to apply the same inline animation for inserted items.
- [ ] 3. Update `public/timeline.css` to add `@keyframes qh-insert`, attribute-selector rules for `[data-semantic="feed-card"]` and `[data-semantic="feed-card"]::after`, and ensure durations match 220ms.
- [ ] 4. Update `index.html` script to query `[data-semantic="feed-card"]` and `[data-semantic="feed-body"]` and toggle `is-at-bottom` appropriately.
- [ ] 5. Run Elm build and Crystal build to ensure nothing breaks; run Playwright diagnostics tests and adjust selectors as needed.
- [ ] 6. Commit changes and update OpenSpec artifacts (mark tasks complete) then archive the change.

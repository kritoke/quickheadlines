Change: fix-timeline-text-contrast

Goal
----
Fix cases on the Timeline view where item link text (and some header text) renders as black on dark backgrounds for certain feeds/sites after client-side re-renders or tab switches.

Background
----------
We recently fixed feed box header/link contrast issues by removing `!important` overrides and avoiding JS forcing colors when Elm provides server colors. That resolved the feedbox problem, but a similar issue still occurs on the Timeline page for a small subset of sites where text becomes black on dark backgrounds.

Hypothesis
----------
- Timeline items sometimes inherit color from parent elements due to stylesheet rules that force `color: inherit` with `!important` (some remaining rules were updated, but timeline-specific selectors still behave differently).
- Elm renders timeline items separately from feed boxes and may not set inline text colors for server-provided colors in the Timeline path.
- Client JS color extraction currently skips elements with `data-use-server-colors="true"` but may still run on timeline items that lack the attribute.

Plan
----
1. Inspect the Timeline rendering in Elm (`ui/src/...`) to confirm where server-provided header/text colors are applied for timeline items and whether `data-use-server-colors` is set there.
2. Add defensive checks and apply inline text colors for timeline items when server provides colors (mirror feedbox behavior). Prefer Elm-side fix so compiled `public/elm.js` is authoritative.
3. Ensure CSS doesn't contain `!important` rules targeting timeline links that can override inline colors. If any exist, remove them or narrow their scope.
4. Update client JS to avoid touching timeline items with server colors; add small debounce/retry to mutation handling for timeline re-renders as needed.
5. Add/extend Playwright test `ui/tests/timeline-contrast.spec.ts` to cover timeline view contrast after tab switches and feed toggles.

Acceptance criteria
-------------------
- Timeline item link text never becomes unreadable (black on dark backgrounds) after switching tabs or theme changes for feeds that have server-provided colors.
- Playwright test `ui/tests/timeline-contrast.spec.ts` passes in CI.

Files to change (proposed)
-------------------------
- `ui/src/` — Elm Timeline view files (apply server color flags and inline color where appropriate)
- `views/index.html` — ensure no remaining `!important` timeline color overrides
- `ui/tests/timeline-contrast.spec.ts` — new Playwright test
- `openspec/changes/fix-timeline-text-contrast/` — implementation notes and tasks

Next step
---------
I will inspect Elm Timeline files to locate where colors should be applied and then implement the minimal Elm + JS + test changes. Proceed with the implementation now? (I'll default to "yes" and create the OpenSpec artifacts and code edits.)

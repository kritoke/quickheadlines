## Context

`clusterOtherItem` links are currently using `htmlAttribute (Html.Attributes.style "color" "inherit")`, which in some contexts (like the new expanded background) might be inheriting a dark color or not explicitly setting the theme-aware `txtColor`. Also, some feeds lack favicons, leading to empty spaces or layout shifts.

## Goals / Non-Goals

**Goals:**
- Ensure all links in story clusters are visible in both Dark and Light modes.
- Implement a robust favicon fallback using Google's S2 service.
- Maintain consistent hover states.

**Non-Goals:**
- Changing the backend's favicon storage logic.

## Decisions

- **Link Styling**: 
  - Explicitly apply `Font.color txtColor` to links in `clusterOtherItem`.
  - Standardize `mouseOver` to `lumeOrange`.
- **Favicon Fallback**:
  - Update `viewIcon` or the calling logic to use `https://www.google.com/s2/favicons?sz=32&domain_url=<site_link>` if the `faviconUrl` is empty or missing.

## Risks / Trade-offs

- **Risk**: Google's favicon service might be blocked or deprecated.
- **Mitigation**: It serves as a secondary fallback; if it fails, we still have the standard placeholder logic.

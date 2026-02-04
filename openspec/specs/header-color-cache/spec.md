# Spec: header-color-cache

Capability: header-color-cache

Purpose
- Store extracted header colors in localStorage to prevent color flashing on page refresh and reduce ColorThief extractions.

Background
- Proposal: Add localStorage caching for header colors. Design: Cache extracted colors with 7-day expiration, apply immediately on page load.

Requirements
1) Cache Header Colors on Extraction
   - When header colors are extracted via ColorThief, they SHALL be stored in localStorage with the current timestamp.
   - Colors are saved under the key `qh_header_colors`.
   - Cache entry includes a timestamp.
   - Cache entry includes the feed URL or favicon key for identification.

2) Apply Cached Colors on Page Load
   - On page load, cached header colors SHALL be applied immediately before ColorThief extraction.
   - System checks localStorage for cached header colors.
   - If cache exists and is not expired, cached colors are applied immediately.
   - Cached colors are applied via inline styles to prevent flash.

3) Cache Expiration
   - Cached colors SHALL expire after 7 days.
   - When cached colors are older than 7 days, ColorThief re-extracts colors.
   - New colors replace the expired cache.
   - When cached colors are less than 7 days old, ColorThief extraction is skipped.

4) Cache Format
   - Cached data SHALL include feed URL or identifier, background color, text color, and timestamp.
   - Format: JSON object with keys as feed URLs/favicon paths and values containing bg, text, and timestamp.

Acceptance criteria
- Header colors persist across page refreshes.
- No color flashing on page load.
- Cache expires after 7 days.
- Extraction is skipped when valid cache exists.

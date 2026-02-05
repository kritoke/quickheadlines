## Why

Timeline items show unreadable text (default muted color) until JavaScript color extraction runs asynchronously. Feed headers initially render with no styling until client-side JavaScript applies cached colors. This causes a flash of unstyled content and inconsistent colors across page loads. Moving color extraction to the server eliminates this delay by pre-computing colors during feed fetch.

## What Changes

- Add `stumpy_png` Crystal dependency for server-side PNG image processing
- Create `src/color_extractor.cr` with YIQ-based dominant color extraction
- Integrate color extraction into `fetcher.cr` after favicon fetching
- Update database storage to persist extracted colors
- Modify client-side JavaScript to use server-provided colors first
- Add configuration option for color re-extraction interval

## Capabilities

### New Capabilities
- `server-color-extraction`: Server-side color extraction from favicons during feed fetch
- `color-persistence`: Persistent storage of extracted colors in database
- `color-cache-sync`: Client-side synchronization with server-provided colors

### Modified Capabilities
- `header-color-cache`: Extend existing header color caching to support server-provided colors

## Impact

- **Dependencies**: Add `stumpy_png` and `stumpy_core` to shard.yml
- **New Code**: `src/color_extractor.cr` (~100 lines)
- **Modified Code**: `src/fetcher.cr`, `src/storage.cr`, `views/index.html`
- **Database**: No schema changes (uses existing `header_color` and `header_text_color` columns)
- **Client**: Reduced JavaScript processing, faster initial render

## Context

Timeline items initially render with default muted colors until client-side JavaScript ColorThief extraction completes. This causes a flash of unreadable text. Feed headers lack styling until JavaScript applies cached colors from localStorage. The existing `/api/header_color` endpoint saves extracted colors to the database, but only after client-side extraction runs.

## Goals / Non-Goals

**Goals:**
- Eliminate flash of unstyled/unreadable content on timeline load
- Pre-compute colors during feed fetch on the server
- Maintain user overrides from `feeds.yml`
- Reduce client-side CPU usage for color extraction

**Non-Goals:**
- Replace all JavaScript color extraction (kept as fallback)
- Modify timeline clustering or sorting logic
- Change visual design of timeline items

## Decisions

### 1. Use stumpy_png for server-side PNG processing

**Decision**: Add `stumpy_png` and `stumpy_core` dependencies for Crystal-based PNG reading.

**Rationale**:
- Pure Crystal implementation, no native dependencies
- Actively maintained with Crystal 1.x support
- Simple API: `StumpyPNG.read(io)` returns canvas with pixel access

**Alternatives considered**:
- Inline PNG parsing: Too complex, error-prone
- Call external tool (ImageMagick): Adds system dependency, subprocess overhead

### 2. YIQ formula for text contrast

**Decision**: Use YIQ luminance formula to compute contrasting text color.

```crystal
yiq = (r * 299 + g * 587 + b * 114) / 1000
text_color = yiq >= 128 ? "#1f2937" : "#ffffff"
```

**Rationale**: Same formula used by client-side ColorThief, ensuring consistency.

### 3. Color extraction timing

**Decision**: Extract colors after favicon is successfully fetched and saved to local filesystem.

**Rationale**:
- Favicon URL known after fetch
- Local file path available for stumpy_png
- Colors saved to DB before feed data returned

### 4. Override prevention

**Decision**: Only extract if `feed.header_color` is nil/empty AND no manual override in config.

**Rationale**:
- User overrides in `feeds.yml` take priority
- Preserve extracted colors across refreshes
- Skip extraction if user has explicitly set colors

## Risks / Trade-offs

**[Risk]** Color extraction quality differs from ColorThief
→ **Mitigation**: Keep client-side extraction as backup; compare results in development

**[Risk]** Slower feed refresh due to image processing
→ **Mitigation**: Cache extracted colors; only re-extract when favicon URL changes

**[Risk]** stumpy_png doesn't support all PNG formats (interlacing, ancillary chunks)
→ **Mitigation**: Graceful fallback; skip extraction if parsing fails

## Open Questions

1. Should we store extraction timestamp to enable periodic re-extraction?
2. Should we support JPEG favicons (require additional dependency)?

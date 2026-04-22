## Context

The current implementation uses custom code in `color_extractor.cr` (604 lines) that:
- Uses `crimage` for image loading
- Implements simple pixel averaging for dominant color
- Has custom WCAG contrast calculations
- Manages its own caching

Prismatiq v0.5.2 provides:
- MMCQ (Median Cut Color Quantization) - industry standard algorithm
- Built-in WCAG accessibility calculations
- Theme detection (light/dark)
- ICO file support
- Security hardening (SSRF protection, path traversal prevention)
- Thread-safe design

## Goals / Non-Goals

**Goals:**
- Replace custom color extraction with Prismatiq
- Maintain backward-compatible API (same method signatures)
- Reduce code complexity (~600 lines → ~200 lines)
- Improve color extraction quality (MMCQ vs averaging)

**Non-Goals:**
- Change external behavior or API
- Add new features beyond color extraction
- Modify frontend color usage

## Decisions

### 1. Wrapper vs Direct Integration

**Decision:** Create a wrapper module that maintains existing API signatures

**Rationale:** 
- Existing code calls `ColorExtractor.theme_aware_extract_from_favicon(...)` 
- Changing these call sites would require extensive refactoring
- Wrapper preserves compatibility while using Prismatiq internally

**Alternative:** Direct integration - Would require changing all call sites in `feed_fetcher.cr`

### 2. RGB Representation

**Decision:** Convert between Prismatiq's `RGB` class and `[r,g,b]` arrays

**Rationale:**
- Current code uses array format: `[255, 128, 0]`
- Prismatiq uses `RGB` class with `r`, `g`, `b` properties
- Need conversion helpers in wrapper

### 3. Instance Management

**Decision:** Create reusable instances of `ThemeDetector` and `AccessibilityCalculator`

**Rationale:**
- These classes are thread-safe and cache results
- Creating one instance per module is more efficient than per-call

### 4. Cache Implementation

**Decision:** Keep existing 7-day TTL cache behavior

**Rationale:**
- Current implementation caches for 7 days
- Prismatiq's `ThemeExtractor` also defaults to 7 days
- Maintains consistent behavior

## Risks / Trade-offs

- **[Risk]** Different color output - MMCQ may produce different dominant colors than averaging
  - **Mitigation:** Test with existing favicons to verify acceptable results
  
- **[Risk]** Breaking API changes in Prismatiq
  - **Mitigation:** Wrapper isolates our code from upstream changes

## Migration Plan

1. Add `prismatiq` to `shard.yml`
2. Run `shards install`
3. Create wrapper module in `color_extractor.cr`
4. Run tests to verify behavior
5. Run `just nix-build` to verify compilation
6. Deploy and monitor color extraction quality

## Open Questions

- Should we expose more Prismatiq features (palette extraction, accessibility reports)?
- Any concerns about the color output difference with MMCQ?

## Why

The current color extraction in QuickHeadlines uses a custom implementation (`color_extractor.cr`) built on top of `crimage` with simple pixel averaging for dominant color detection. This implementation has grown to 600+ lines with duplicated WCAG contrast calculations. Prismatiq is a modern Crystal shard that provides the same functionality using the industry-standard MMCQ (Median Cut Color Quantization) algorithm (same as Color Thief), with built-in WCAG accessibility, theme detection, and security hardening.

## What Changes

- **Add Prismatiq dependency** to `shard.yml` (v0.5.2)
- **Replace color_extractor.cr** with a thin wrapper around Prismatiq's APIs
- **Remove crimage dependency** - Prismatiq handles image loading internally
- **Preserve existing API** - Keep method signatures compatible for backward compatibility
- **Update tests** - Adapt to new implementation

## Capabilities

### New Capabilities
- `prismatiq-integration`: Integration with Prismatiq shard for color extraction (new implementation)

### Modified Capabilities
- `color-extraction`: The existing color extraction capability will use Prismatiq internally instead of custom code. Requirements remain the same (extract dominant color from favicon, generate WCAG-compliant text colors).

## Impact

- **Code**: `src/color_extractor.cr` - Replaced with wrapper module
- **Dependencies**: Add `kritoke/prismatiq` to `shard.yml`, remove direct `crimage` usage
- **Tests**: `spec/color_extractor_*.cr` - May need updates for new implementation
- **Functionality**: Same external behavior, better color extraction algorithm (MMCQ vs averaging)

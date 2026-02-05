## 1. Dependencies

- [x] 1.1 Add stumpy_png and stumpy_core to shard.yml
- [x] 1.2 Run `shards install` to fetch new dependencies
- [x] 1.3 Verify crystal build compiles with new dependencies

## 2. Color Extractor Module

- [x] 2.1 Create src/color_extractor.cr with ColorExtractor module
- [x] 2.2 Implement StumpyPNG.read() for loading favicon files
- [x] 2.3 Implement dominant_color() method using pixel sampling
- [x] 2.4 Implement contrasting_text_color() using YIQ formula
- [x] 2.5 Add extraction result caching by favicon path

## 3. Integration with Fetcher

- [x] 3.1 Modify get_favicon() to call color extraction after successful fetch
- [x] 3.2 Check for user overrides in feed config before extracting
- [x] 3.3 Update FeedData to include extracted colors
- [x] 3.4 Modify update_or_create_feed() to save colors to DB
- [x] 3.5 Add extraction timestamp tracking

## 4. Database Updates

- [x] 4.1 Verify feeds table has header_color and header_text_color columns
- [x] 4.2 Ensure get_timeline_items() returns colors in API responses
- [x] 4.3 Verify colors included in cluster item queries

## 5. Client-Side Updates

- [x] 5.1 Update views/index.html extractHeaderColors() to check server colors first
- [x] 5.2 Modify applyCachedHeaderColors() to prefer server-provided values
- [x] 5.3 Update JavaScript to skip extraction for feeds with server colors
- [x] 5.4 Sync localStorage with server colors on page load

## 6. Testing

- [x] 6.1 Run crystal spec to verify no regressions
- [x] 6.2 Test color extraction with sample favicons
- [x] 6.3 Verify user overrides work correctly
- [x] 6.4 Test timeline renders with colors on first load
- [x] 6.5 Verify graceful fallback when extraction fails

## 7. Build Verification

- [x] 7.1 Run `nix develop . --command crystal build src/quickheadlines.cr`
- [x] 7.2 Verify ameba passes (pre-existing issues only)
- [x] 7.3 Test with development server

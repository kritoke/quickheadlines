## 1. In-Memory Favicon Cache

- [ ] 1.1 Add `FaviconCache` module with in-memory `String` -> `Bytes` cache in `src/favicon_cache.cr`
- [ ] 1.2 Limit cache size (max 200 entries, LRU eviction)
- [ ] 1.3 Integrate cache into `ProxyController#favicon_file` — check cache before disk, store after read
- [ ] 1.4 Add cache warming at startup (pre-load existing favicon files into memory)

## 2. Browser Caching Headers

- [x] 2.1 Add `Cache-Control: public, max-age=604800, immutable` to favicon responses
- [x] 2.2 Add `Cache-Control: public, max-age=86400` to proxy-image responses

## 3. Background Task Yielding

- [ ] 3.1 Add `Fiber.yield` between iterations in `FaviconSyncService#process_missing_backfills`
- [ ] 3.2 Add `Fiber.yield` between iterations in `FaviconSyncService#process_google_backfills`
- [ ] 3.3 Add `Fiber.yield` in feed refresh loop between concurrent batch waits

## 4. Server Configuration

- [ ] 4.1 Increase `HTTP::Server` backlog from default (128) to 256
- [ ] 4.2 Enable `reuse_port` if supported by the OS

## 5. Diagnosis and Root Cause

- [ ] 5.1 Add request timing logging to identify which endpoint blocks longest
- [ ] 5.2 Identify the specific operation that causes the event loop to freeze
- [ ] 5.3 Fix the root cause based on diagnosis findings

## 6. Verification

- [ ] 6.1 Server runs for 5+ minutes without freezing under load test
- [ ] 6.2 `just nix-build` succeeds
- [ ] 6.3 All 163 Crystal tests pass

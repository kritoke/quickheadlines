## 1. Implementation

- [x] 1.1 Modify `UrlNormalizer.normalize` in `src/utils.cr` to strip query parameters (text after `?`)
- [x] 1.2 Modify `UrlNormalizer.normalize` in `src/utils.cr` to strip fragments (text after `#`)

## 2. Verification

- [x] 2.1 Run `just nix-build` to verify build passes
- [x] 2.2 Run `nix develop . --command crystal spec` to verify all tests pass
- [x] 2.3 Verify manually with URL like `https://example.com/article?utm_source=twitter` that normalization strips query params

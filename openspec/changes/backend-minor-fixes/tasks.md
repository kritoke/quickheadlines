## 1. MIME Type Fix

- [x] 1.1 Fix `.woff` MIME mapping from `font/woff2` to `font/woff` in utils.cr

## 2. Error Handling Precision

- [x] 2.1 Narrow `rescue Exception` to `rescue ArgumentError` in `ApiBaseController#check_admin_auth`
- [x] 2.2 Replace `rescue nil` with `rescue ex` + `Log.for("AppBootstrap").warn` in `AppBootstrap#close`
- [x] 2.3 Add logging to `AdminController#parse_admin_action` rescue blocks for `IO::EOFError` and `JSON::ParseException`

## 3. HTTP Timeout Standardization

- [x] 3.1 Update `FaviconStorage` HTTP client to use `Constants` timeout values
- [x] 3.2 Update `ProxyController` HTTP client to use `Constants` timeout values

## 4. IP Extraction Consolidation

- [x] 4.1 Move `TRUSTED_PROXY`-aware IP extraction logic to `Utils` module as a shared method
- [x] 4.2 Update `ApiBaseController#client_ip` to call shared Utils method
- [x] 4.3 Update `quickheadlines.cr` WebSocket handler to call shared Utils method
- [x] 4.4 Remove old `extract_client_ip` from utils.cr (replaced by shared method)

## 5. Verification

- [x] 5.1 Run `just nix-build` and verify compilation succeeds
- [x] 5.2 Run `nix develop . --command crystal spec` and verify tests pass

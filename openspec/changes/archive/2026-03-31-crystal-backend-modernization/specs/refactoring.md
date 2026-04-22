## Summary

This change is a **pure refactoring** with no user-facing capability changes. All HTTP endpoints, WebSocket behavior, database schemas, and configuration file formats remain identical.

## ADDED Requirements

This section is intentionally empty — no new user-facing capabilities are being introduced.

## MODIFIED Requirements

This section is intentionally empty — no existing requirement behaviors are being changed.

## Notes on Internal Implementation Changes

While not new user-facing requirements, the following internal implementation changes are being made:

### Dependency Injection Container
- All services (`FeedCache`, `FeedFetcher`, `DatabaseService`, etc.) are registered with Athena's ADI framework
- All `@@instance` singleton patterns are removed
- Services are injected via constructors

### Structured Logging
- All `STDERR.puts` calls are replaced with Crystal's `Log` module
- Log sources are namespaced (e.g., `Log.for("quickheadlines.feed_service")`)

### Module Organization
- All `Quickheadlines` modules renamed to `QuickHeadlines`
- Free functions converted to module methods (`def self.load`)
- Database time format extracted to `Constants::DB_TIME_FORMAT`

### Controller Organization
- `ApiController` (902 lines) split into 6 focused controllers
- No URL routing changes

---

**Verification:** After each phase of this refactoring, the existing test suite (`crystal spec`) and build (`just nix-build`) MUST pass with no changes to behavior.

# Proposal: extract-fetcher-shard

## Summary
Extract all feed-pulling and parsing logic from the QuickHeadlines monolith into a standalone Crystal shard named `fetcher.cr`. This shard will handle RSS, Atom, Reddit JSON, and Software Release protocols via a unified driver-based architecture.

## Motivation
- **Portability:** Allow the fetcher to be published as a standalone library.
- **Resilience:** Isolate messy XML/JSON parsing and HTTP networking from the Athena web core.
- **Extensibility:** Easily add new "Drivers" (e.g., YouTube, Mastodon, or Scrapers) without touching the main application logic.
- **Nix-Native Testing:** Enable isolated testing of network protocols within a clean Nix shell.

## Scope
- Create a local shard structure in `shared/fetcher`.
- Define a unified `Fetcher::Entry` DTO for all drivers.
- Implement `RSSDriver` (XML), `RedditDriver` (JSON), and `SoftwareDriver` (GitHub/GitLab/Codeberg).
- Ensure support for HTTP Conditional Requests (ETags / Last-Modified).

## Constraints
- **Zero-Persistence:** The shard must not have dependencies on SQLite or any Repository.
- **Pure Input/Output:** It takes a URL/Headers and returns an Array of Entries.
- **Nix-Locked:** All dependencies resolved via the Nix Flake.
- **Stdlib Only:** Use Crystal's native `HTTP::Client` for networking (no external HTTP shards).

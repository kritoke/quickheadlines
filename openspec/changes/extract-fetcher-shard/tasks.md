# Tasks: extract-fetcher-shard

- [x] **Task 1: Scaffold Shard**
  - [x] Initialize `shared/fetcher` directory structure
  - [x] Configure `shard.yml` (no external HTTP deps - stdlib only)
  - [x] Verify build works with nix develop

- [x] **Task 2: Define Core Interfaces**
  - [x] Implement `Fetcher::Entry` record
  - [x] Implement `Fetcher::Result` record
  - [x] Create the `Fetcher::Driver` abstract base class

- [x] **Task 3: Implement Drivers**
  - [x] Port RSS/Atom logic into `Fetcher::RSSDriver`
  - [x] Implement `Fetcher::RedditDriver` for subreddit JSON parsing
  - [x] Implement `Fetcher::SoftwareDriver` for GitHub/GitLab/Codeberg

- [x] **Task 4: HTTP Client with ETag Support**
  - [x] Implement HTTP wrapper using stdlib `HTTP::Client`
  - [x] Add ETag/Last-Modified conditional request handling
  - [x] Add retry logic with exponential backoff

- [x] **Task 5: Main Fetcher Entry Point**
  - [x] Implement `Fetcher.pull(url, headers)` method
  - [x] Implement protocol detection (RSS vs Reddit vs Software)
  - [x] Return unified `Fetcher::Result`

- [x] **Task 6: Main App Integration**
  - [x] Link the local shard in the main `shard.yml`
  - [x] Create `src/fetcher_adapter.cr` to bridge Fetcher shard with main app
  - [x] Update `feed_fetcher.cr` to use new shard for software releases

- [x] **Task 7: Validation**
  - [x] Run `nix develop --command crystal spec shared/fetcher`
  - [x] Run `just nix-build` to verify full build
  - [x] Run main app specs

## Completed
- Shard compiles and passes all 12 tests
- Main app builds successfully
- Integration adapter created for software releases

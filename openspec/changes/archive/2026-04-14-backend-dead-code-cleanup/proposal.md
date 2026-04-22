## Why

The Crystal backend has ~760 lines of dead code accumulated from incomplete refactors, scaffolded-but-unimplemented features, and abandoned architecture migrations. This dead code increases maintenance burden, confuses new contributors, and slows the compiler. A `crystal tool unreachable` analysis confirmed every method and function listed below has zero runtime callers.

## What Changes

- Remove ~500 lines of dead code with zero behavior change
- Delete unused `Result(T, E)` type system (`result.cr`) and all `*_result` method variants
- Delete unused `FeedService` class and its lazy accessor in `ApiBaseController`
- Delete unused DTOs: `FeedDTO`, `StatusResponse`, `VersionResponse`, `ApiErrorResponse`
- Delete unused `TimelineItem` record and `Domain::FeedItem` record
- Delete 19 unreachable `ColorExtractor` methods (~138 lines)
- Delete 18 unreachable global functions across `utils.cr`, `config/loader.cr`, `config/github_sync.cr`, `parser.cr`, `storage/cache_utils.cr`, `storage/database.cr`
- Delete 13 unreachable `FeedCache` delegation methods and their 9 matching `ClusteringStore` methods
- Delete 12 unreachable repository methods across `FeedRepository`, `StoryRepository`, `ClusterRepository`
- Delete 4 unreachable service methods across `StoryService`, `ClusteringService`
- Delete empty `services/feed_state.cr` module
- Delete unused `crimage` shard dependency from `shard.yml`
- Remove unused `ConfigState` record and `ClusteringConfig#enabled?` method
- Remove unused error type aliases (`FetchResult`, `SoftwareFetchResult`, `RedditFetchResult`)
- Clean up `application.cr` require statements for removed files

## Capabilities

### New Capabilities

(none — this is a pure cleanup change)

### Modified Capabilities

(none — no spec-level behavior changes, only dead code removal)

## Impact

- **Code**: ~20 files modified or deleted across `src/`
- **Build**: Faster compilation from reduced codebase
- **Dependencies**: `crimage` shard removed from `shard.yml` and `shard.lock`
- **API**: Zero — no endpoint behavior changes
- **Tests**: Crystal spec suite should pass unchanged

## Context

The QuickHeadlines backend (~6,500 lines of Crystal across 67 files) has accumulated technical debt from multiple incomplete refactoring efforts. Two major refactors were started but never finished:

1. **Entity/DTO/Repository pattern migration**: `entities/` and `domain/` directories were created with new record types, but the bulk of the application still uses `models.cr` records (`FeedData`, `Item`, `Tab`)
2. **Athena DI adoption**: `@[ADI::Register]` annotations were added to services and repositories, but all controllers bypass the DI container via manual singletons

Additionally, `favicon_data` handling is broken across multiple layers — timeline responses always get `nil`, cluster items get the wrong field copied, and the DTO exposes internal filesystem paths to the frontend.

The architecture follows an Outside-In design: DTOs are the stable public contract with the Svelte 5 frontend, entities are internal persistence details, and `models.cr` records are runtime state objects used during feed processing.

## Goals / Non-Goals

**Goals:**
- Remove all dead code and unused declarations
- Eliminate dual patterns (two serialization approaches, two DI systems, two transaction styles)
- Fix broken `favicon_data` propagation in timeline and cluster responses
- Simplify `FeedCache` initialization (remove dual DB init path)
- Break the circular dependency between `DatabaseService` and `Application`
- Preserve the public API contract (DTOs remain stable)

**Non-Goals:**
- Migrating `FeedData`/`Item`/`Tab` to entities (these are runtime state objects, not persistence entities)
- Renaming or namespacing top-level classes (`FeedFetcher`, `AppBootstrap`, etc.) — cosmetic, deferred
- Removing `FaviconSyncService` — still needed for data migration of existing feeds
- Touching the heat map subsystem (future feature, left alone)
- Database schema changes

## Decisions

### D1: Make `TimelineEntry` a private struct inside `StoryRepository`

**Decision:** Convert `Domain::TimelineEntry` from a public module record to a private struct inside `StoryRepository`.

**Rationale:** `TimelineEntry` is only used by `StoryRepository.find_timeline_items()` (as return type) and `StoryService.get_timeline()` (as input, immediately destructured into DTOs). It's a private implementation detail of the repository that leaks into the service layer. Making it private eliminates the `domain/` directory entirely.

**Alternative considered:** Return `Array(TimelineItemResponse)` directly from `StoryRepository`. Rejected — repositories should not construct DTOs; that's the service's job.

### D2: Standardize on `JSON::Serializable` for all DTOs

**Decision:** Remove `ASR::Serializable` from `ConfigResponse`, `ClustersResponse`, `ClusterItemsResponse`, and `StoryResponse`.

**Rationale:** `JSON::Serializable` is already used by the majority of DTOs (`FeedResponse`, `TimelineItemResponse`, `FeedsPageResponse`, `TabsResponse`). The Athena serializer integration (`ASR`) was adopted for newer DTOs but creates inconsistency. `JSON::Serializable` is simpler, has no framework dependency, and is what the legacy DTOs use.

**Alternative considered:** Migrate everything to `ASR::Serializable`. Rejected — it would require changes to all existing DTOs and ties serialization to Athena's framework.

### D3: Remove `Entities::Feed` and add `find_all_urls()` to `FeedRepository`

**Decision:** Delete `entities/feed.cr` and `read_feed_entity()`. Add `find_all_urls() : Set(String)` to `FeedRepository`.

**Rationale:** `Entities::Feed` has exactly one consumer (`AdminController.handle_cleanup_orphaned`) which only accesses `.url`. The entire `read_feed_entity()` method and `find_all()` exist solely for this one use case. A simple `SELECT url FROM feeds` query is sufficient.

**Alternative considered:** Keep `Entities::Feed` and fix it. Rejected — it's a ghost of an incomplete refactor with no real consumers.

### D4: Pass config explicitly to `DatabaseService` instead of reading from `Application`

**Decision:** Remove `DatabaseService.instance` class-level singleton and the forward declaration. `AppBootstrap` creates `DatabaseService.new(config)` and passes it to consumers.

**Rationale:** The current pattern requires a forward declaration of `QuickHeadlines::Application` in `database_service.cr` to break a circular require. This is fragile and confusing. Passing config explicitly eliminates the circular dependency entirely.

**Migration:** `AppBootstrap` already receives config and creates services. It will create `DatabaseService.new(config)` and pass it to `FeedCache.new(config, db_service)`. The `DatabaseService.instance` class method will be removed.

### D5: Remove `favicon_data` from `FeedResponse` DTO

**Decision:** Delete the `favicon_data` property from `FeedResponse` in `api_responses.cr`.

**Rationale:** The frontend uses the `favicon` field (a URL path like `/favicons/abc123.png`) to request images via the proxy endpoint. It never reads `favicon_data`. The field exposes internal filesystem paths to the API, which is both unnecessary and a minor information leak.

**Impact check needed:** Verify the frontend does not reference `favicon_data` on feed objects before removing.

## Risks / Trade-offs

- **[Risk] Removing `DatabaseService.instance` may break code that accesses it** → Audit all `.instance` call sites and update them to receive `DatabaseService` via constructor or `AppBootstrap`
- **[Risk] Removing `favicon_data` from `FeedResponse` may break frontend** → Grep frontend codebase for `favicon_data` references before removing
- **[Risk] Changing `FeedCache` constructor signature breaks callers** → Only 2 callers exist (`load_feed_cache` and tests), both easily updated
- **[Trade-off] Keeping `models.cr` records as-is** → `FeedData`, `Item`, `Tab` are runtime state objects that work well for their purpose. Forcing them into an entity pattern would be over-engineering.

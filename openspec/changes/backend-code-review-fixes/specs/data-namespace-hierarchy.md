# data-namespace-hierarchy

**Owner:** Backend Team  
**Status:** proposed

## Overview

Consistent namespace hierarchy under `QuickHeadlines::` for all application types. Eliminates top-level types that can collide with Crystal stdlib and third-party shards.

## Requirements

### REQ-001: Constants Namespace
`Constants` module becomes `QuickHeadlines::Constants`.

### REQ-002: State Namespace
`StateStore` module becomes `QuickHeadlines::State::StateStore`.

### REQ-003: Storage Namespace
- `DatabaseService` → `QuickHeadlines::Storage::DatabaseService`
- `FeedCache` facade → `QuickHeadlines::Storage::FeedCache`
- `ClusteringRepository` module → `QuickHeadlines::Storage::ClusteringRepository`
- `HeaderColorsRepository` module → `QuickHeadlines::Storage::HeaderColorsRepository`
- `CleanupRepository` module → `QuickHeadlines::Storage::CleanupRepository`

### REQ-004: Domain Namespace
- `QuickHeadlines::Domain::FeedItem`
- `QuickHeadlines::Domain::TimelineEntry`

### REQ-005: Mixins Retained at Module Level
The mixin modules (`ClusteringRepository`, `HeaderColorsRepository`, `CleanupRepository`) retain their names but live under `QuickHeadlines::Storage::`. Types that include them remain unchanged.

### REQ-006: Require Statements Updated
All `require` statements across all `.cr` files are updated to reference new namespace paths.

## Acceptance Criteria

- [ ] `QuickHeadlines::Constants` is the only constants module
- [ ] `QuickHeadlines::State::StateStore` is the only state store
- [ ] All types are under `QuickHeadlines::` namespace
- [ ] No top-level application types exist (outside `QuickHeadlines::`)
- [ ] All `require` statements compile without errors

## Affected Files

All `.cr` files — mechanical namespace updates throughout the codebase.

## Non-Affected

- Third-party shard types (athena, sqlite3, lexis-minhash, etc.)
- Crystal stdlib types

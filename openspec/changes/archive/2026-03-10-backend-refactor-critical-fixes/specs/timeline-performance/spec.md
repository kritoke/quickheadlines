# Timeline Performance

## Overview

This spec covers the timeline endpoint performance improvements, specifically eliminating N+1 query patterns when fetching timeline items with cluster information.

## ADDED Requirements

### Requirement: Timeline query uses single query with JOINs

The timeline endpoint SHALL fetch all timeline items with their cluster information in a single database query using SQL JOINs instead of N+1 per-item queries.

#### Scenario: Timeline fetch returns items with cluster data
- **WHEN** client requests `/api/timeline` with limit=35
- **THEN** system executes exactly ONE query that JOINs items, feeds, and cluster data
- **AND** returns all items with `cluster_id`, `is_representative`, and `cluster_size` fields populated

#### Scenario: Timeline respects date range filter
- **WHEN** client requests `/api/timeline?days_back=14`
- **THEN** system filters items to only those within the date range in the same single query
- **AND** does not make additional queries per item for cluster information

#### Scenario: Timeline pagination works correctly
- **WHEN** client requests `/api/timeline?limit=500&offset=0`
- **AND** then requests `/api/timeline?limit=500&offset=500`
- **THEN** both requests use the same optimized single-query pattern
- **AND** return correct paginated results

### Requirement: Cluster representative selection

The timeline SHALL only show cluster representative items (one per cluster) to avoid duplicates in the timeline view.

#### Scenario: Cluster shows only representative item
- **GIVEN** a cluster has 5 items with the same `cluster_id`
- **WHEN** timeline fetches items
- **THEN** only the item with the lowest `id` in that cluster is returned as `is_representative: true`
- **AND** other items are excluded from timeline results

### Requirement: Cluster size accurate

The timeline SHALL return accurate cluster size for each clustered item.

#### Scenario: Cluster size reflects all items in cluster
- **GIVEN** a cluster has 5 items
- **WHEN** timeline returns the representative item
- **THEN** `cluster_size` field equals 5

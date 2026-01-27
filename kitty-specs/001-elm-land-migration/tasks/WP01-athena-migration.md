---
description: "WP01: Athena Migration & Cluster DTO"
lane: "doing"
agent: "worker-coder"
shell_pid: "86843"
---

# WP01: Athena Migration & Cluster DTO

## Constitutional Requirements
> **Reference:** QuickHeadlines Constitution v1.1.0
> - **Environment:** All commands MUST use `nix develop --command <command>`
> - **DTOs:** Use strictly typed DTOs with `JSON::Serializable` for all API responses
> - **Services:** Database logic must be encapsulated in Athena Services, not global variables

## Goal
Move clustering logic from `src/quickheadlines.cr` into a structured API with Athena controllers and DTOs.

## Actions

### 1. Setup Athena
Add `athena` to `shard.yml` and initialize the framework.

### 2. Create DTO
Create `src/dtos/news_cluster_dto.cr`. Map existing cluster fields (title, timestamp) to this DTO using `JSON::Serializable`.

### 3. Route Refactor
Move the logic from the `/` route into a `NewsController` that returns `Array(NewsClusterDTO)`.

### 4. Service Extraction
Isolate the `MinHash` and SQLite fetch logic into a standalone `ClusterService`.

## Definition of Done
`GET /api/clusters` returns a JSON array of your existing clusters.

## Implementation Steps

### Step 1: Add Athena to shard.yml
- Add athena dependency to `shard.yml`
- Run `nix develop --command shards install`

### Step 2: Create NewsClusterDTO
- Create `src/dtos/news_cluster_dto.cr`
- Include fields: id, title, timestamp, source_count
- Use `JSON::Serializable` for automatic serialization

### Step 3: Create ClusterService
- Extract MinHash logic from quickheadlines.cr
- Extract SQLite query logic
- Create service class with method to fetch all clusters

### Step 4: Create NewsController
- Create `src/controllers/news_controller.cr`
- Add `GET /api/clusters` route
- Return `Array(NewsClusterDTO)` from service

### Step 5: Update application.cr
- Register NewsController with Athena
- Ensure proper route mounting

## Activity Log

- 2026-01-27T11:00:34Z – worker-coder – shell_pid=86843 – lane=doing – Started implementation via workflow command

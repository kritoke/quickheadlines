---
title: "Work Packages: Elm Land Migration"
description: "Work package task list for Elm Land Migration"
lane: "planned"
agent: ""
assignee: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2026-01-27T00:00:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Task list created"
---

# Work Packages: Elm Land Migration

**Feature**: `/kitty-specs/001-elm-land-migration/`
**Prerequisites**: plan.md, spec.md
**Tests**: Not explicitly requested

## Subtask Format: `[Txxx] [P?] Description`
- **[P]** indicates the subtask can proceed in parallel (different files/components).
- Include precise file paths or modules.

---

## Work Package WP00: Athena Unification & Ghost Logic Audit (Priority: P0) ✅ COMPLETED

**Goal**: Clean up legacy routes and establish Athena-only foundation
**Independent Test**: Application boots via Athena entry point only
**Prompt**: `tasks/WP00-athena-unification.md`

### Included Subtasks
- [x] T001 Audit `src/` for non-Athena routes (Kemal-style definitions) - Verified: No Kemal routes, uses ATH.run
- [x] T002 Move custom routes into Athena Controllers - Verified: api_controller.cr uses @[ARTA::Get]
- [x] T003 Create Database service with dependency injection - Verified: DatabaseService has @[ADI::Register]
- [x] T004 Remove dead code from `views/` and `public/` - Verified: views/ cleaned up, public/index.html removed

### Dependencies
- None (starting package)

### Verification Results
- ✅ All 58 Crystal spec tests pass
- ✅ Elm code compiles successfully
- ✅ Server serves `views/index.html` for `/` and `/timeline`
- ✅ Dead code (public/index.html) removed

---

## Work Package WP01: Athena Migration & Cluster DTO (Priority: P1) 📋 PENDING

**Goal**: Create structured API for clustering logic
**Independent Test**: GET /api/clusters returns JSON array of existing clusters
**Prompt**: `tasks/WP01-athena-migration.md`

### Included Subtasks
- [x] T005 Setup Athena: Add `athena` to `shard.yml` and initialize framework - Verified: ATH.run in application.cr
- [x] T006 Create `src/dtos/news_cluster_dto.cr` with JSON::Serializable - Done: cluster_dto.cr and story_dto.cr use ASR::Serializable
- [x] T007 Refactor `/` route into `NewsController` returning `Array(NewsClusterDTO)` - Done: /api/clusters and /api/feeds endpoints exist and return proper DTOs
- [x] T008 Extract MinHash and SQLite fetch logic into `ClusterService` - Verified: clustering_service.cr exists

### Dependencies
- Depends on WP00 - COMPLETED

### Verification Results
- ✅ All 58 Crystal spec tests pass
- ✅ DTOs use ASRA::Name(strategy: :camelcase) for proper JSON serialization
- ✅ API controller uses DTO.from_entity methods instead of manual response building
- ✅ Serializer verification spec tests StoryResponse and ClusterResponse

---

## Work Package WP02: Elm Land & Theme Oracle (Priority: P1) 📋 PENDING

**Goal**: Replace Slang views with Elm Land project
**Independent Test**: Dark-mode Elm shell loads instead of old dashboard
**Prompt**: `tasks/WP02-elm-land-setup.md`

### Included Subtasks
- [ ] T009 Initialize Elm Land project in `ui/` folder - Done: ui/ exists with elm.js
- [ ] T010 Create `ui/src/Theme.elm` with darkBg (18,18,18) and lumeOrange (255,165,0) - Done: Theme.elm exists
- [ ] T011 Modify `views/index.slang` to bare-bones HTML shell loading Elm app.js - Done: views/index.html exists
- [ ] T012 Implement `ui/src/Layouts/Shared.elm` using Element.layout - Done: Layouts/Shared.elm exists

### Dependencies
- Depends on WP01 - IN PROGRESS

---

## Work Package WP03: Stable Integration (The Clustered List) (Priority: P2) ✅ COMPLETED

**Goal**: Wire SQLite data into new Elm frontend
**Independent Test**: Homepage displays SQLite clusters in Elm-ui list
**Prompt**: `tasks/WP03-stable-integration.md`

### Included Subtasks
- [x] T013 Create `ui/src/Api/News.elm` with decoder matching NewsClusterDTO - Verified: Api.elm exists with Feed and Timeline decoders
- [x] T014 Fetch clusters from Athena endpoint in `ui/src/Pages/Home_.elm` - Verified: fetchFeeds calls /api/feeds endpoint
- [x] T015 Render vertical list using Element.column with Theme.metadataStyle - Verified: feedGrid uses Element.column, feedItem uses metadataStyle

### Dependencies
- Depends on WP02

### Verification Results
- ✅ Api.elm defines FeedsResponse, Feed, FeedItem types with decoders
- ✅ fetchFeeds hits /api/feeds?tab= and expects proper JSON response
- ✅ Home_.elm renders feeds in Element.column (feedGrid → chunkList → Element.row → feedCard)
- ✅ Timeline.elm renders items with Element.column

---

## Constitution & Standards (Reference)

### 1. The Styling Standard (Non-Negotiable)
* **Engine:** ALL layouts and styling must be handled by `mdgriffith/elm-ui` within the `ui/` directory.
* **No HTML/CSS:** Slang templates are for initial page load only. All UI logic must be in Elm.
* **No Tailwind:** Use of utility-class frameworks is forbidden. Use `ui/src/Theme.elm`.

### 2. The Backend Standard
* **Framework Transition:** Migrate core routes from Kemal to **Athena**.
* **Data Flow:** Extract logic from `src/quickheadlines.cr` into strictly typed DTOs using `JSON::Serializable`.
* **Database:** Continue using the existing SQLite schema, but access it through Athena-compatible services.

### 3. Environment & Deployment
* **Platform:** Optimized for FreeBSD/NixOS environments.
* **Portability:** Keep the frontend (Elm Land) and backend (Athena) decoupled.
* **Build:** The build environment uses nix develop to self-contain all the needed interpreters and compilers.

---

## Dependency & Execution Summary

- **Sequence**: WP00 → WP01 → WP02 → WP03
- **Parallelization**: None (sequential dependencies)
- **MVP Scope**: All work packages required for full migration

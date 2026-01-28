---
work_package_id: "WP00"
subtasks:
  - "T001"
  - "T002"
  - "T003"
  - "T004"
title: "WP00: Athena Unification & Ghost Logic Audit"
phase: "Phase 1 - Foundation Cleanup"
lane: "for_review"
assignee: "worker-coder"
agent: "worker-coder"
shell_pid: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2026-01-27T00:00:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# WP00: Athena Unification & Ghost Logic Audit

## Goal
The project has partially migrated to Athena, but legacy Custom routes or global database handlers may still exist. We need a clean "Athena-only" foundation.

## Actions

### 1. Audit `src/`
Identify any routes defined outside of Athena Controllers (e.g., Kemal `get "/"`, `post "/"` blocks).

### 2. Controller Migration
Move any remaining custom routes into their respective Athena Controllers.

### 3. Database Service
Ensure SQLite connection logic is not global. Move it into an `App::Services::Database` (or similar) that can be injected into Athena Controllers.

### 4. Remove Dead Code
Delete old `views/` or `public/` files that are strictly for the old backend and won't be used by Elm Land.

## Definition of Done
The application boots strictly via the Athena entry point, and all functional routes are managed by Athena Controllers.

## Implementation Steps

### Step 1: Audit src/ for non-Athena routes
- Search for Kemal-style route definitions (`get "`, `post "`, `put "`, `delete "`)
- Check `src/application.cr` for Kemal configuration
- Check for any `Kemal.config` usage

### Step 2: Identify global database handlers
- Search for `DB` or `database` usage outside of service classes
- Check `src/storage.cr` and related files
- Look for global variables or constants accessing the database

### Step 3: Create Database service with DI
- Create `src/services/database_service.cr`
- Ensure it can be injected into controllers via constructor injection

### Step 4: Migrate routes to Athena Controllers
- Create or update controllers in `src/controllers/`
- Ensure all routes go through Athena framework

### Step 5: Remove legacy files
- Identify files in `views/` that are no longer needed
- Identify files in `public/` that are for old backend only
- Delete or archive unused files

## Activity Log

- 2026-01-27T10:52:50Z – worker-coder – lane=for_review – Ready for review: Athena unification complete, DatabaseService created with DI

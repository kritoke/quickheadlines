---
title: "Specification: Migrating Elm UI to Elm Land"
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
    action: "Specification created"
---

# Specification: Migrating Elm UI to Elm Land

## Context
Currently, the project uses a Crystal Athena backend (API) and a manual Elm UI frontend. We are migrating the frontend to **Elm Land** to take advantage of its file-based routing, built-in layouts, and standardized project structure.

## Requirements
1. **Routing:** Migrate all existing manual routes to the `src/Pages` directory in Elm Land.
2. **State Management:** Adapt the current `Model` and `Msg` to Elm Land's `Effect` and `Shared` state pattern.
3. **UI/Styling:** Port existing Elm UI components into Elm Land views.
4. **Backend Integration:** Ensure the Elm Land `Auth` and `Api` modules correctly interface with the existing Crystal Athena endpoints.
5. **Layouts:** Implement a consistent Header/Footer using Elm Land's Layout system.

## Out of Scope
- Rewriting Crystal Athena controllers (unless API contract changes are required).
- Database schema changes.

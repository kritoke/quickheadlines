# QuickHeadlines Constitution (OpenSpec Edition)

> **Version:** 1.2.0
> **Guiding Principle:** Type-safe architecture, minimal dependencies, and environment-locked development.

## 1. Environment & Execution (The Nix Rule)
* **Mandatory Shell:** ALL commands MUST be executed via `nix develop`.
* **No Global Tools:** Never use system-installed Crystal, Elm, or Shards. If a tool is missing, add it to `flake.nix`.
* **Environment Target:** Must remain compatible with **FreeBSD Jails** and **NixOS (aarch64)**. Avoid Linux-only syscalls.

## 2. Technical Standards
### Backend (The Athena Engine)
* **Framework:** Crystal **Athena** is the source of truth.
* **Data Handling:** Strictly typed **DTOs** with `JSON::Serializable`.
* **Serialization:** Use `Athena::Serializer`. Never manually stringify JSON.
* **Database:** SQLite via `crystal-sqlite3`, encapsulated in Athena Services.

### Frontend (The Elm Land UI)
* **Framework:** **Elm Land** with `mdgriffith/elm-ui`.
* **Styling:** ALL layouts MUST use `Element` primitives. 
* **FORBIDDEN:** `Html`, `Html.Attributes`, `class` tags, Tailwind, or CSS frameworks.

### Architecture (The Headless Split)
* **Decoupling:** Backend (JSON API) and Frontend (SPA) must remain independent.
* **Logic:** Use `Result(T, E)` patterns for fallible operations. No `as_any` or untyped hashes.

## 3. Work Process (The OpenSpec Workflow)
* **Task Discipline:** Agents must create a Change Proposal (`/opsx:new`) before writing code.
* **Single Source of Truth:** Beads and Spec Kitty WPs are replaced by `openspec/changes/`.
* **Anti-Regression:** Before any change, the agent MUST read `openspec/archive/` to ensure architectural decisions aren't being reverted.

## 4. Definition of Done (Verification)
* **Testing:** A change is only complete when it passes:
  1. `nix develop . --command crystal spec`
  2. `nix develop . --command ameba`
  3. `nix develop . --command elm-land build`
* **Archival:** Use `/opsx:archive <name>` for all completed changes to merge them into the permanent specs.
* **Landing the Plane (Session Completion):** 
  1. **Sync:** Run `git pull --rebase`.
  2. **Push:** Execute `git push` and verify `git status` shows "up to date with origin".
  3. **Cleanup:** Clear any stashes or temporary local branches.
  4. **Handoff:** Provide a summary of work completed and context for the next session.

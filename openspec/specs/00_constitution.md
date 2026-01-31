# QuickHeadlines Constitution (OpenSpec Edition)

> **Version:** 1.3.0
> **Guiding Principle:** Type-safe architecture, minimal dependencies, environment-locked development, and strict frontend primitives.

## 1. Environment & Execution (The Nix Rule)
* **Mandatory Shell:** ALL commands MUST be executed via `nix develop . --command <command>` (the project workspace must be the target of the devshell). Do not run tooling directly from the host shell.
* **No Global Tools:** Do not rely on system-installed Crystal, Elm, or Shards. If a required tool is missing from the devshell, it MUST be added to `flake.nix` so the environment is reproducible.
* **Cross-Platform:** Development tooling and scripts must work identically on FreeBSD, Linux, and macOS when invoked through the Nix devshell. Avoid host-specific syscalls or paths.

## 2. Technical Standards
### Backend (The Athena Engine)
* **Framework:** Crystal **Athena** is the standard runtime.
* **Data Handling:** Use strictly typed DTOs with `JSON::Serializable` for all API responses and internal transports.
* **Database:** Use SQLite via `crystal-sqlite3`; all DB access must be wrapped in Athena Services (no global DB variables).
* **Serialization:** Use `Athena::Serializer` for JSON serialization; never hand-string JSON or rely on ad-hoc hash structures.

### Frontend (The Elm Land UI)
* **Framework:** Elm Land with `mdgriffith/elm-ui` (Element primitives).
* **Standard Styling:** ALL UI layout and interactive components MUST be implemented using `Element` primitives. Treat `Element` as the canonical DOM abstraction for the project.
* **Strictly Forbidden:** Direct use of `Html`, `Html.Attributes`, raw `class` attributes, Tailwind, or other CSS frameworks for layout or component structure. Stylesheets may be used for global variables and conservative overrides (e.g., theme variables), but structural/layout work belongs in Element.
* **State & Effects:** Use Elm Land's file-based routing and Effect patterns for API calls and side effects.

### Architecture (The Headless Split)
* **Decoupling:** The backend is a JSON API and the frontend is a static SPA; they must remain technically independent so the backend can be ported or replaced without changing the UI.
* **Fallible Logic:** Use `Result(T, E)` (or Athena's equivalent) patterns for fallible operations. Avoid `as_any`, `JSON.parse` into untyped hashes, or other untyped structures.

### Code Quality & Standards
These rules ensure maintainability and preserve refactors made during Element migration.

#### Implementation Rules
* **Type Safety:** No `as_any`, no untyped hashes — use DTOs for all external and internal data.
* **Error Handling:** Prefer `Result(T, E)` or Athena's exception listeners; the server must not crash on malformed inputs such as bad RSS feeds.
* **Bento-Readiness:** Build UI components as modular Element primitives to support future layout changes (grid, embedding, etc.).

#### Documentation & Maintenance
* **ADRs:** Any change that adds a new Shard or Elm package MUST include a short ADR-style note in the PR explaining the reason and alternatives considered.
* **Minimalism:** Treat each new dependency as a liability; prefer standard library or core framework features first.

#### Preserve Refactors
* **Non-Reversion Guarantee:** Refactors that migrate the codebase to Element primitives or that enforce the Nix Rule must not be reverted without explicit review. Agents MUST consult `openspec/archive/` and the change history before reverting architectural refactors; reversion requires an explicit OpenSpec Change that documents the rationale.

## 3. Work Process (The OpenSpec Workflow)
* **Change Workflow:** Agents must create a Change Proposal (`/opsx:new`) before implementing code changes; use `/opsx:apply` to make iterative edits and `/opsx:archive` when complete.
* **Single Source of Truth:** `openspec/changes/` is the canonical location for all Change artifacts.
* **Anti-Regression:** Before starting work, consult `openspec/archive/` and `openspec/changes/` to avoid re-introducing regressions or undoing prior refactors (particularly Element migrations and Nix environment changes).

## 4. Definition of Done (Verification)
* **Testing:** A change is only complete when it passes the relevant test/build steps from within the Nix devshell (examples):
  1. `nix develop . --command crystal spec`
  2. `nix develop . --command ameba`
  3. `nix develop . --command elm-land build` or `nix develop . --command npx playwright test` where applicable
* **ADRs & PR Notes:** PRs that add dependencies must include an ADR-style note explaining why the dependency is needed.
* **Archival:** All completed changes MUST be archived with `/opsx:archive <name>` to update main specs.
* **Landing the Plane (Session Completion):**
  1. **Verify:** Run `git pull --rebase`.
  2. **Push:** Execute `git push` and verify `git status` shows "up to date with origin".
  3. **Cleanup:** Clear any stashes and prune temporary branches.
  4. **Handoff:** Provide a short summary and next actions for the follow-up session.

# QuickHeadlines Constitution

> **Version:** 1.1.0
> **Last Updated:** 2026-01-27
> **Guiding Principle:** Type-safe architecture, minimal dependencies, and environment-locked development.

## 1. Environment & Execution (The Nix Rule)

* **Mandatory Shell:** ALL commands must be executed via `nix develop --command <command>`.
* **No Global Tools:** Do not attempt to use system-installed Crystal, Elm, or Shards. If a tool is missing, it must be added to the `flake.nix`.
* **Cross-Platform:** Development is standardized via Nix to ensure identical behavior on FreeBSD, Linux, and macOS.

## 2. Technical Standards

### Backend (The Athena Engine)

* **Framework:** Crystal **Athena** is the standard.
* **Data Handling:** Use strictly typed **DTOs** with `JSON::Serializable` for all API responses.
* **Database:** SQLite via `crystal-sqlite3`. Database logic must be encapsulated in Athena Services, not global variables.
* **Serialization:** Never manually stringify JSON; always use `Athena::Serializer`.

### Frontend (The Elm Land UI)

* **Framework:** **Elm Land** with `mdgriffith/elm-ui`.
* **Standard Styling:** ALL layouts must use `Element` primitives. **Strictly Forbidden:** `Html`, `Html.Attributes`, `class` tags, and Tailwind/CSS frameworks.
* **State:** Use Elm Land’s file-based routing and `Effect` pattern for API calls.

### Architecture (The Headless Split)

* **Decoupling:** The backend is a JSON API. The frontend is a static SPA. They must remain technically independent to allow for future backend porting (e.g., to F#).

## 3. Code Quality & Standards

### Implementation Rules

* **Type Safety:** No `as_any` or `JSON.parse` into untyped hashes. Use DTOs for everything.
* **Error Handling:** Use `Result(T, E)` patterns or Athena's built-in exception listeners. Never let the server crash on a malformed RSS feed.
* **Bento Preparedness:** While not yet active, all UI components must be built as modular `Elements` to support a future grid layout.

### Documentation & Maintenance

* **ADRs:** Any change that adds a new Shard or Elm package requires a brief "Why" note in the PR.
* **Minimalism:** Every new dependency is a liability. Prefer standard library or core framework features first.

## 4. Work Process (Spec Kitty Mode)

* **Task Discipline:** Agents must follow the `tasks.md` Work Packages (WPs) in order.
* **Status Updates:** Update the "Status" field in `tasks.md` to `[doing]` when starting and `[done]` when verified.
* **Verification:** A task is not `[done]` until it passes `nix develop --command crystal spec` and `nix develop --command elm-land build`.
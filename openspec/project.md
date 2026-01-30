# QuickHeadlines Project Constitution

## 🛠️ Tech Stack & Patterns
- **Language:** Crystal using the **Athena Framework**.
- **Patterns:** - Use `Result(T, E)` for all fallible operations. 
  - Prefer **Composition over Inheritance**.
  - No "Simplification": Do not revert `Athena::Serializer` logic to standard JSON mapping.
- **Frontend:** **Elm Land**. Maintain file-based routing; do not bypass Elm Land's architecture.

## 🏗️ Architecture Guardians
- **Model Integrity:** Never revert refactored logic in `src/models`.
- **Error Handling:** Avoid raising exceptions for flow control. Use the established `Result` pattern.
- **Environment:** Must remain compatible with **FreeBSD Jails** and **NixOS**. Avoid Linux-only syscalls.

## 🧪 Quality Standards
- **Testing:** 80% coverage minimum via `crystal spec`.
- **E2E:** Playwright (using the Nix-native browsers defined in the Hub Flake).
- **Documentation:** All public-facing methods in `src/services` must be documented.
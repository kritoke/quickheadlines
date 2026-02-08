# Project: QuickHeadlines (Lumnitide)

## 🎯 Primary Goal
A high-performance news aggregator built for FreeBSD Jails and NixOS, utilizing Crystal (Athena) and Elm (elm-pages v3).

## 🛠 Tech Stack
- **Backend:** Crystal + Athena (Headless JSON API)
- **Frontend:** Elm Pages v3 + elm-ui (Hybrid Rendering)
- **Environment:** Nix Flakes (Mandatory for all `nix develop --command` execution)

## 📜 Global Rules
1. **No HTML/CSS:** All UI layout must use `Element` primitives from `elm-ui`.
2. **Semantic Hooks:** Every component must have `Theme.semantic` attributes (`data-name`).
3. **Spec-Driven:** Every code change MUST be preceded by an `/opsx` artifact.
4. **Environment:** Assume aarch64-linux (NixOS) or FreeBSD. No glibc assumptions.
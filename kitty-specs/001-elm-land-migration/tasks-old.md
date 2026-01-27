# 📜 Project Constitution & Standards

## 1. The Styling Standard (Non-Negotiable)
* **Engine:** ALL layouts and styling must be handled by `mdgriffith/elm-ui`.
* **No HTML/CSS:** Use of `Html`, `Html.Attributes`, or `Html.Events` for layout (div, span, img, class, style) is strictly forbidden.
* **No Frameworks:** No Tailwind, Bootstrap, or external CSS files.
* **Type-Safety:** Colors and spacing must be pulled from `ui/src/Theme.elm`.

## 2. The Backend Standard
* **Framework:** Athena (Crystal).
* **Data Flow:** Use strictly typed DTOs (Data Transfer Objects) with `JSON::Serializable`.
* **Contract:** The backend serves JSON; the frontend consumes it via `Api.News` decoders.

## 3. Environment & Deployment
* **Platform:** Optimized for FreeBSD/NixOS environments.
* **Portability:** Keep the frontend (Elm Land) and backend (Athena) decoupled.

---

## planned
- [ ] **WP03: Auth Handshake Integration**
  - Implement `Auth.elm` in Elm Land to intercept protected routes.
  - Connect `onAuthCheck` to the Athena `/api/me` endpoint.
  - Handle redirection logic for unauthenticated users.
  - [P] Bead: `bd create "WP03: Elm Land Auth Handshake"`

- [ ] **WP05: Implement Global Layouts**
  - Create `src/Layouts/Sidebar.elm` for RSS category navigation.
  - Register the layout in `src/Pages/Home_.elm`.

- [ ] **WP06: Production Build & Asset Routing**
  - Update Crystal Athena `static_file_handler` to serve the `dist/` folder.
  - Verify `elm-land build` produces a minified bundle that Athena can serve.

## doing

## for_review
- [ ] **WP02: Athena Serializer Verification**
  - Final audit: Ensure all JSON keys are CamelCase.
  - Bead: `bd create "WP02: Final Serializer Audit"`

- [ ] **WP04: Port Core Views (Elm UI to Elm Land)**
  - Port existing RSS Feed logic from old frontend to `src/Pages/Home_.elm`.
  - Ensure Elm UI `Element` code is wrapped correctly in Elm Land `View` types.
  - [P] Bead: `bd create "WP04: Porting RSS Views"`

## for_review

## done
- [x] **WP00: Project Initialization**
- [x] **WP01: Initialize Elm Land and Shared State**
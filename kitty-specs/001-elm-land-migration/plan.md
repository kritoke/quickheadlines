# Plan: Auth Implementation

- **Phase 1: Athena Preparation**
  - Audit existing `AuthController.cr` to ensure JSON compatibility with Elm.
- **Phase 2: Elm Land Scaffolding**
  - Run `elm-land add auth` to generate the authentication boilerplate.
- **Phase 3: Handshake Logic**
  - Implement the `onAuthCheck` function in `Auth.elm` to call the Athena `/me` endpoint.
- **Phase 4: Login UI**
  - Port the Elm UI login form to an Elm Land Page (`src/Pages/Login.elm`).

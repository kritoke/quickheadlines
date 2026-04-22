## 1. Implement fix in src/quickheadlines.cr

- [x] 1.1 Remove `start_server_async` helper function
- [x] 1.2 Inline handler construction (ClientIPHandler, WebSocketHandler) in main begin block
- [x] 1.3 Call `ATH.run` synchronously (not spawned) on main thread
- [x] 1.4 Spawn `bootstrap.start_background_tasks` and `bootstrap.verify_feeds_loaded` before `ATH.run`

## 2. Build and verify

- [x] 2.1 Run `just nix-build` — must pass
- [x] 2.2 Run `nix develop . --command crystal spec` — tests pass
- [x] 2.3 Verify port-binding error handling by temporarily using an occupied port

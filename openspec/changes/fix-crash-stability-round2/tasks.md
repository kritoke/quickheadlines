## 1. SQLite Stability

- [x] 1.1 Add busy_timeout=5000 and max_pool_size=5 to DatabaseService connection string
- [x] 1.2 Add PRAGMA mmap_size = 0 and wal_autocheckpoint = 100 to DatabaseService.create_schema
- [x] 1.3 Add PRAGMA mmap_size = 0, wal_autocheckpoint = 100, and foreign_keys = ON to top-level create_schema in database.cr

## 2. HTTP::Client Cleanup

- [x] 2.1 Wrap proxy_controller HTTP::Client in begin/ensure with client.close
- [x] 2.2 Add write_timeout to proxy_controller HTTP::Client
- [x] 2.3 Wrap favicon_storage fetch_and_save HTTP::Clients in begin/ensure with close
- [x] 2.4 Add write_timeout to favicon_storage HTTP::Clients
- [x] 2.5 Add timeouts to github_sync.cr HTTP::Client.get call

## 3. Feed Fetch Deadlock Guard

- [x] 3.1 Add timeout to channel.receive in fetch_feeds_concurrently
- [x] 3.2 Ensure spawned fibers always send to channel in ensure block
- [x] 3.3 Add StateStore.clustering? guard to async_clustering entry

## 4. Build Verification

- [x] 4.1 Run just nix-build to verify compilation
- [x] 4.2 Run crystal spec tests
- [x] 4.3 Run frontend tests

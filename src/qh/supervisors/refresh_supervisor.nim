## Refresh supervisor (design D5) - runs the feed refresh in its own thread with
## its own DbConn, so it never blocks the HTTP server (which serves reads from
## the main connection; WAL lets the two coexist). Does an immediate refresh on
## start, then repeats every intervalSec (0 = one-shot initial refresh only).

import std/[os]
import ../types
import ../storage/[database, feed_store]
import ../fetcher/[http_fetcher, fetch_pipeline]

type
  RefreshArgs = object
    feedConfigs: seq[FeedConfig]
    dbPath: string
    intervalSec: int

proc refreshLoop(a: RefreshArgs) {.thread.} =
  # ORC is thread-safe at runtime; assert gcsafe without transitive checks.
  {.cast(gcsafe).}:
    let db = openAndCreate(a.dbPath)
    let store = SqliteFeedStore(db: db)
    let fetcher = newHttpFetcher()
    while true:
      let s = fetcher.refreshAll(a.feedConfigs, store, 8)
      echo "[refresh] fetched=", s.fetched, " failed=", s.failed, " items=", s.items
      if a.intervalSec <= 0: break       # one-shot
      sleep(a.intervalSec * 1000)
    closeDb(db)

proc startRefreshSupervisor*(feedConfigs: seq[FeedConfig]; dbPath: string;
                             intervalSec = 0): Thread[RefreshArgs] =
  ## Spawn the refresh thread (detached). Returns the handle. intervalSec<=0
  ## means a single immediate refresh then exit.
  createThread(result, refreshLoop,
               RefreshArgs(feedConfigs: feedConfigs, dbPath: dbPath,
                           intervalSec: intervalSec))

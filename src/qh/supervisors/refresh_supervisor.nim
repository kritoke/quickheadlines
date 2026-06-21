## Refresh supervisor (design D5) - runs the feed refresh in its own thread with
## its own DbConn, so it never blocks the HTTP server (which serves reads from
## the main connection; WAL lets the two coexist). Does an immediate refresh on
## start, then repeats every intervalSec (0 = one-shot initial refresh only).

import std/[os, atomics]
import ../storage/[database, feed_store]
import ../fetcher/[http_fetcher, fetch_pipeline, software_fetcher]

type
  RefreshArgs = object
    feedConfigs: seq[FeedConfig]
    swRepos: seq[string]
    dbPath: string
    intervalSec: int
    dirty: ref Atomic[bool]        # set after each refresh -> WS feed_update push

proc refreshLoop(a: RefreshArgs) {.thread.} =
  {.cast(gcsafe).}:
    let db = openAndCreate(a.dbPath)
    let store = SqliteFeedStore(db: db)
    let fetcher = newHttpFetcher()
    while true:
      let s = fetcher.refreshAll(a.feedConfigs, store, a.dirty, 8)
      echo "[refresh] fetched=", s.fetched, " failed=", s.failed, " items=", s.items
      # Fetch software releases if repos configured.
      if a.swRepos.len > 0:
        let swFeed = fetchSoftwareReleases(a.swRepos)
        if swFeed.items.len > 0:
          discard store.upsertWithItems(swFeed)
          echo "[sw-releases] ", swFeed.items.len, " releases from ", a.swRepos.len, " repos"
      a.dirty[].store(true)          # final notify
      if a.intervalSec <= 0: break   # one-shot
      sleep(a.intervalSec * 1000)
    closeDb(db)

proc startRefreshSupervisor*(feedConfigs: seq[FeedConfig];
                             swRepos: seq[string];
                             dbPath: string;
                             dirty: ref Atomic[bool];
                             intervalSec = 0): Thread[RefreshArgs] =
  createThread(result, refreshLoop,
               RefreshArgs(feedConfigs: feedConfigs, swRepos: swRepos,
                           dbPath: dbPath, intervalSec: intervalSec, dirty: dirty))

## Refresh supervisor (design D5) - runs the feed refresh in its own thread with
## its own DbConn, so it never blocks the HTTP server (which serves reads from
## the main connection; WAL lets the two coexist). Does an immediate refresh on
## start, then repeats every intervalSec (0 = one-shot initial refresh only).

import std/[os, atomics, tables]
import ../storage/[database, feed_store, content_store]
import ../fetcher/[http_fetcher, fetch_pipeline, software_fetcher]

type
  RefreshArgs = object
    feedConfigs: seq[FeedConfig]
    swRepos: seq[string]
    dbPath: string
    intervalSec: int
    dirty: ref Atomic[bool]        # set after each refresh -> WS feed_update push
    shuttingDown: ptr Atomic[bool]  # checked each cycle for graceful shutdown

proc refreshLoop(a: RefreshArgs) {.thread.} =
  {.cast(gcsafe).}:
    let db = openAndCreate(a.dbPath)
    let store = SqliteFeedStore(db: db)
    let contentStore = SqliteContentStore(db: db)
    let fetcher = newHttpFetcher()
    # Consecutive-failure watchdog: after skipThreshold consecutive failures,
    # a feed is skipped for most cycles (frees the pool for healthy feeds) but
    # is re-probed every `reprobeEvery` cycles so a transiently-broken feed
    # that recovers isn't permanently dead.
    var failCounts: Table[string, int]
    var cycleCount = 0
    const skipThreshold = 3
    const reprobeEvery = 10      # re-attempt chronically-failing feeds every 10th cycle
    const batchDeadlineMs = 300_000   # 5 min hard budget for the entire batch
    # Clear ALL stored colors on startup so the watcher re-extracts with the
    # final algorithm (WCAG-validated, unified for both theme modes).
    # This is aggressive but the watcher processes 8 feeds per 3s tick (~5 min).
    store.clearAllColors()
    while true:
      if a.shuttingDown != nil and a.shuttingDown[].load():
        echo "[refresh] shutting down"
        break
      inc cycleCount
      # Filter out feeds at/above the skip threshold — except on a re-probe
      # cycle, where every feed is retried so transient outages can clear.
      let isReprobeCycle = cycleCount mod reprobeEvery == 0
      var activeFeeds = newSeq[FeedConfig]()
      var skipped = 0
      for fc in a.feedConfigs:
        if failCounts.getOrDefault(fc.url, 0) >= skipThreshold and not isReprobeCycle:
          inc skipped
        else:
          activeFeeds.add(fc)
      if skipped > 0:
        echo "[refresh] skipping ", skipped, " feed(s) with >= ", skipThreshold,
             " consecutive failures"
      let s = fetcher.refreshAll(activeFeeds, store, contentStore, a.dirty, 4,
                                 batchDeadlineMs)
      # Update consecutive-failure counts.
      for url in s.failedUrls:
        failCounts[url] = failCounts.getOrDefault(url, 0) + 1
        if failCounts[url] == skipThreshold:
          echo "[refresh] ", url, " reached ", skipThreshold,
               " consecutive failures; will skip future cycles"
      for fc in activeFeeds:
        if fc.url notin s.failedUrls:
          failCounts[fc.url] = 0
      echo "[refresh] fetched=", s.fetched, " failed=", s.failed, " items=", s.items
      # Fetch software releases if repos configured.
      if a.swRepos.len > 0:
        let swFeed = fetchSoftwareReleases(a.swRepos)
        if swFeed.items.len > 0:
          discard store.upsertWithItems(swFeed)
          echo "[sw-releases] ", swFeed.items.len, " releases from ", a.swRepos.len, " repos"
      # Cleanup old content entries periodically.
      let cleaned = contentStore.cleanupOldEntries()
      if cleaned > 0: echo "[content] cleaned ", cleaned, " old entries"
      a.dirty[].store(true)          # final notify
      if a.intervalSec <= 0: break   # one-shot
      # Interruptible sleep: 1s chunks checking shutdown flag.
      for _ in 0 ..< a.intervalSec:
        if a.shuttingDown != nil and a.shuttingDown[].load(): break
        sleep(1000)
    closeDb(db)

proc startRefreshSupervisor*(feedConfigs: seq[FeedConfig];
                             swRepos: seq[string];
                             dbPath: string;
                             dirty: ref Atomic[bool];
                             intervalSec = 0;
                             shuttingDown: ptr Atomic[bool] = nil): Thread[RefreshArgs] =
  createThread(result, refreshLoop,
               RefreshArgs(feedConfigs: feedConfigs, swRepos: swRepos,
                           dbPath: dbPath, intervalSec: intervalSec, dirty: dirty,
                           shuttingDown: shuttingDown))

## Cleanup supervisor - periodic background job that deletes items older than
## cache_retention_hours and runs a WAL checkpoint. Keeps the DB from growing
## unbounded (the Crystal cache_retention_hours default: 14 days = 336h).
## Runs in its own thread with its own DbConn.

import std/[os, atomics]
import ../storage/database   # purgeOldItems, openAndCreate, closeDb

type
  CleanupArgs = object
    dbPath: string
    cacheRetentionHours: int
    intervalSec: int
    dirty: ref Atomic[bool]

proc cleanupLoop(a: CleanupArgs) {.thread.} =
  {.cast(gcsafe).}:
    let db = openAndCreate(a.dbPath)
    while true:
      sleep(a.intervalSec * 1000)
      try:
        purgeOldItems(db, a.cacheRetentionHours)
        a.dirty[].store(true)
        echo "[cleanup] retention=", a.cacheRetentionHours, "h"
      except CatchableError:
        discard
    closeDb(db)

proc startCleanupSupervisor*(dbPath: string; cacheRetentionHours = 336;
                             intervalSec = 1800;
                             dirty: ref Atomic[bool] = nil): Thread[CleanupArgs] =
  ## Spawn the cleanup thread. intervalSec default 30min; retention default 14 days.
  createThread(result, cleanupLoop,
               CleanupArgs(dbPath: dbPath,
                           cacheRetentionHours: cacheRetentionHours,
                           intervalSec: intervalSec, dirty: dirty))

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
    shuttingDown: ptr Atomic[bool]

proc cleanupLoop(a: CleanupArgs) {.thread.} =
  {.cast(gcsafe).}:
    let db = openAndCreate(a.dbPath)
    while true:
      for _ in 0 ..< a.intervalSec:
        if a.shuttingDown != nil and a.shuttingDown[].load():
          echo "[cleanup] shutting down"
          closeDb(db)
          return
        sleep(1000)
      try:
        purgeOldItems(db, a.cacheRetentionHours)
        a.dirty[].store(true)
        echo "[cleanup] retention=", a.cacheRetentionHours, "h"
      except CatchableError as e:
        echo "[cleanup] ERROR: ", e.msg

proc startCleanupSupervisor*(dbPath: string; cacheRetentionHours = 336;
                             intervalSec = 1800;
                             dirty: ref Atomic[bool] = nil;
                             shuttingDown: ptr Atomic[bool] = nil): Thread[CleanupArgs] =
  createThread(result, cleanupLoop,
               CleanupArgs(dbPath: dbPath,
                           cacheRetentionHours: cacheRetentionHours,
                           intervalSec: intervalSec, dirty: dirty,
                           shuttingDown: shuttingDown))

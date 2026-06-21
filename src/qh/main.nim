## QuickHeadlines (Nim) - main entrypoint.
##
## Wires the production boundaries into the App composition root, does an
## initial feed refresh so there is data to serve, then starts the HTTP API.
##
## Build: nim c -d:ssl --threads:on -o:bin/quickheadlines src/qh/main.nim
## Run:   ./bin/quickheadlines   (QUICKHEADLINES_CONFIG, QUICKHEADLINES_DB,
##                                QUICKHEADLINES_PORT env vars optional)

import std/[os, strutils, times, atomics]
import types
import config/config_source
import config/yaml_config
import storage/[database, feed_store, item_store, cluster_store]
import fetcher/[http_fetcher, fetch_pipeline]
import clustering/clusterer
import in_memory/services
import app
import web/server
import supervisors/refresh_supervisor
import supervisors/cluster_supervisor
import supervisors/cleanup_supervisor
import security/rate_limiter

proc envInt(key: string; dflt: int): int =
  try: getEnv(key, $dflt).parseInt() except ValueError: dflt

proc main() =
  let cfgPath = getEnv("QUICKHEADLINES_CONFIG", "feeds.yml")
  let dbPath  = getEnv("QUICKHEADLINES_DB", "qh_nim.db")
  let port    = envInt("QUICKHEADLINES_PORT", 8080)

  # 1. config
  let cfgSrc = YamlConfigSource(path: cfgPath)
  let cfgR = cfgSrc.load()
  if not cfgR.isOk:
    echo "Failed to load config ", cfgPath, ": err=", cfgR.err, " (set QUICKHEADLINES_CONFIG)"
    quit(1)
  var config = cfgR.config
  echo "Loaded config: ", config.tabs.len, " tab(s), page_title=\"", config.pageTitle, "\""

  # 2. open DB + build the production stores
  let db = openAndCreate(dbPath)
  let feedStore    = SqliteFeedStore(db: db)
  let itemStore    = SqliteItemStore(db: db)
  let clusterStore = SqliteClusterStore(db: db)

  # 3. App composition root (validates every boundary composes - concepts
  #    enforced at compile time; in-memory impls stand in for not-yet-prod ones).
  discard newApp(
    newHttpFetcher(), newNimClusterer(), feedStore, itemStore, clusterStore,
    InMemoryBroadcaster(subscribers: 0), cfgSrc,
    InMemoryHealthReporter(healthyFlag: true, detail: "feeds refreshing"),
    InMemoryRateLimiter(budget: 60), InMemoryProxyValidator())

  # 4. Build the feed list from config.
  var feedConfigs: seq[FeedConfig]
  for t in config.tabs:
    for f in t.feeds: feedConfigs.add(FeedConfig(url: f.url, title: f.title))

  # Software release repos parsed from feeds.yml tabs (Option[YamlSoftwareReleases]).
  # Parse software_release repos from the YAML file (NimYAML can't parse
  # optional nested objects; repos are extracted with a line-based parser).
  let swRepos = yaml_config.parseSwRepos(cfgPath)
  config.swRepos = swRepos
  if swRepos.len > 0:
    echo "Software repos: ", swRepos.len, " configured"

  # 5. Refresh in a background thread (its own DbConn).
  var dirty: ref Atomic[bool]
  new(dirty); dirty[].store(false)
  discard startRefreshSupervisor(feedConfigs, swRepos, dbPath, dirty, config.refreshMinutes * 60)
  echo "Refresh running in background (", feedConfigs.len, " feeds, ", swRepos.len, " software repos); serving reads now."

  # 6. Periodic clustering (its own DbConn; threshold from config).
  let cc = config.clustering
  let clInterval = if cc.runOnStartup: 1 else: 3600  # 1s if startup-run (first tick), then 1h
  let clThreshold = cc.threshold
  discard startClusterSupervisor(dbPath, threshold = clThreshold,
                                  maxItems = cc.maxItems.clamp(1, 5000),
                                  intervalSec = clInterval, dirty = dirty)
  echo "Cluster supervisor started (threshold=", clThreshold, " interval=", clInterval, "s)"

  # 7. Periodic cleanup (its own DbConn; retention from config).
  discard startCleanupSupervisor(dbPath, cacheRetentionHours = 336,
                                 intervalSec = 1800, dirty = dirty)
  echo "Cleanup supervisor started (retention=336h interval=30min)"

  # 6. Serve the read API + embedded SPA + WS push. (Blocks; main thread.)
  let limiter = newRateLimiter(limit = 1000, windowSec = 60.0)
  let ctx = ServerCtx(
    config: config, feedStore: feedStore, itemStore: itemStore,
    startedAtMs: now().utc().toTime().toUnix() * 1000'i64,
    dirty: dirty, rateLimiter: limiter)
  ctx.serve(port)

when isMainModule: main()

## Shared domain types and concrete per-boundary result types.
##
## Why concrete (not generic Result[T,E]) result types: Phase-1 finding F1/F3 -
## Nim 2.2.4 concepts and default-instantiation under threads can't handle a
## generic Result with an unresolved error param. Each fallible boundary gets
## its own concrete `XResult` object so `concept`s can enforce the contract.
## The generic `Result[T,E]` in results.nim remains available for non-boundary
## internal code.

import std/tables

# ---------------------------------------------------------------- core domain

type
  Item* = object
    title*: string
    link*: string
    pubDate*: string          ## ISO 8601 string (UTC); parsed to Time at edges
    content*: string
    version*: string
    commentUrl*: string
    commentaryUrl*: string

  FeedData* = object
    ## Output of fetching+ parsing a single feed (port of Crystal FeedData).
    title*: string
    url*: string
    siteLink*: string
    items*: seq[Item]
    etag*: string
    lastModified*: string
    favicon*: string
    headerColor*: string
    headerTextColor*: string

  FeedRow* = object
    ## A stored feed row (port of the feeds table shape).
    id*: int64
    url*: string
    title*: string
    siteLink*: string
    favicon*: string
    faviconData*: string
    headerColor*: string
    headerTextColor*: string
    headerThemeColors*: string   # JSON string: {"bg":"#rrggbb","text":{"light":"#rrggbb","dark":"#rrggbb"}}

  ClusteringItem* = object
    id*: int64
    title*: string
    feedId*: int64
    feedUrl*: string

  TimelineEntry* = object
    ## Port of Crystal TimelineEntry (story_repository.cr).
    id*: int64
    title*: string
    link*: string
    pubDate*: string
    feedTitle*: string
    feedUrl*: string
    feedLink*: string
    favicon*: string
    headerColor*: string
    headerTextColor*: string
    clusterId*: int64          ## 0 == no cluster
    representative*: bool
    clusterSize*: int
    commentUrl*: string
    commentaryUrl*: string

  Cluster* = Table[int64, seq[int64]]   ## representative id -> member ids

# ---------------------------------------------------------------- config (port of structures.cr)

type
  Feed* = object
    title*: string
    url*: string
    headerColor*: string
    headerTextColor*: string
    itemLimit*: int            ## 0 == unset

  ClusteringConfig* = object
    enabled*: bool
    runOnStartup*: bool
    maxItems*: int             ## 0 == unset
    maxFetchItems*: int
    threshold*: float

  TabConfig* = object
    name*: string
    feeds*: seq[Feed]

  Config* = object
    debug*: bool
    refreshMinutes*: int
    pageTitle*: string
    itemLimit*: int
    dbFetchLimit*: int
    serverPort*: int
    timelineBatchSize*: int
    feeds*: seq[Feed]
    tabs*: seq[TabConfig]
    clustering*: ClusteringConfig
    swRepos*: seq[string]     # software release repos (from feeds.yml)

# ---------------------------------------------------------------- error enums (concrete)

type
  FetchError* = enum feHttp, feParse, feNetwork
  StoreError* = enum seNotFound, seConflict, seIo, seSchema
  ClusterError* = enum ceNoInput, ceInconsistent
  ConfigError* = enum ceMissing, ceMalformed, ceInvalid
  BroadcastError* = enum beNoSubscribers, beClosed
  RateLimitError* = enum rlExceeded
  ProxyError* = enum pePrivateIp, peMalformed, peBlocked

# ---------------------------------------------------------------- concrete per-boundary result types

type
  FetchResult* = object
    isOk*: bool
    data*: FeedData
    err*: FetchError

  ClusterResult* = object
    isOk*: bool
    clusters*: Cluster
    err*: ClusterError

  TimelineResult* = object
    isOk*: bool
    entries*: seq[TimelineEntry]
    total*: int
    err*: StoreError

  FeedListResult* = object
    isOk*: bool
    feeds*: seq[FeedRow]
    err*: StoreError

  StoreUnitResult* = object
    isOk*: bool
    err*: StoreError

  ConfigResult* = object
    isOk*: bool
    config*: Config
    err*: ConfigError

  BroadcastResult* = object
    isOk*: bool
    sent*: int
    err*: BroadcastError

  RateLimitResult* = object
    isOk*: bool            ## isOk == allowed
    remaining*: int
    err*: RateLimitError

  ProxyValidateResult* = object
    isOk*: bool
    resolvedIp*: string
    err*: ProxyError

# ---------------------------------------------------------------- result constructors

template makeOk*(T: typedesc): untyped =
  ## Unit-style ok for result types whose success has no payload fields set.
  T(isOk: true)

proc okFetch*(d: FeedData): FetchResult = FetchResult(isOk: true, data: d)
proc errFetch*(e: FetchError): FetchResult = FetchResult(isOk: false, err: e)

proc okCluster*(c: Cluster): ClusterResult = ClusterResult(isOk: true, clusters: c)
proc errCluster*(e: ClusterError): ClusterResult = ClusterResult(isOk: false, err: e)

proc okTimeline*(e: seq[TimelineEntry], total: int): TimelineResult =
  TimelineResult(isOk: true, entries: e, total: total)
proc errTimeline*(e: StoreError): TimelineResult = TimelineResult(isOk: false, err: e)

proc okFeeds*(f: seq[FeedRow]): FeedListResult = FeedListResult(isOk: true, feeds: f)
proc errFeeds*(e: StoreError): FeedListResult = FeedListResult(isOk: false, err: e)

proc okStore*(): StoreUnitResult = StoreUnitResult(isOk: true)
proc errStore*(e: StoreError): StoreUnitResult = StoreUnitResult(isOk: false, err: e)

proc okConfig*(c: Config): ConfigResult = ConfigResult(isOk: true, config: c)
proc errConfig*(e: ConfigError): ConfigResult = ConfigResult(isOk: false, err: e)

proc okBroadcast*(sent: int): BroadcastResult = BroadcastResult(isOk: true, sent: sent)
proc errBroadcast*(e: BroadcastError): BroadcastResult = BroadcastResult(isOk: false, err: e)

proc allowRate*(remaining: int): RateLimitResult = RateLimitResult(isOk: true, remaining: remaining)
proc denyRate*(e: RateLimitError; remaining = 0): RateLimitResult =
  RateLimitResult(isOk: false, remaining: remaining, err: e)

proc okProxy*(ip: string): ProxyValidateResult = ProxyValidateResult(isOk: true, resolvedIp: ip)
proc errProxy*(e: ProxyError): ProxyValidateResult = ProxyValidateResult(isOk: false, err: e)

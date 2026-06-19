## Black-box boundary concepts (design D4).
##
## Every boundary returns a CONCRETE result type from types.nim (Phase-1 F1:
## concepts can't enforce generic Result[T,E] returns). This module is the
## contract between modules; concrete impls (production + in-memory test) live
## elsewhere and MUST satisfy these concepts. tests/test_concept_checks.nim
## enforces it at compile time.

import ./types

# ---------------------------------------------------------------- Fetcher

type
  Fetcher* = concept c
    ## Fetches one feed URL -> parsed FeedData or error.
    c.fetch("https://x") is FetchResult

# ---------------------------------------------------------------- Clusterer

type
  Clusterer* = concept c
    ## Assigns items to clusters given a batch; returns rep -> members.
    c.cluster(@[ClusteringItem()]) is ClusterResult

# ---------------------------------------------------------------- Stores

type
  FeedStore* = concept c
    ## Feeds table CRUD (port of feed_repository.cr feed side).
    c.upsertFeed(FeedRow()) is StoreUnitResult
    c.listFeeds() is FeedListResult

  ItemStore* = concept c
    ## Item queries (port of story_repository.cr timeline).
    c.findTimeline(30, 0, 14) is TimelineResult

  ClusterStore* = concept c
    ## LSH band storage + cluster assignment (port of clustering_store.cr).
    c.assignClusters(Cluster()) is StoreUnitResult
    c.clearClusters() is StoreUnitResult

# ---------------------------------------------------------------- push / config / ops

type
  Broadcaster* = concept c
    ## Push events to WebSocket subscribers (port of event_broadcaster.cr).
    c.broadcast("{}") is BroadcastResult

  ConfigSource* = concept c
    ## Read feeds.yml + env + defaults (port of config/loader.cr).
    c.load() is ConfigResult

  HealthReporter* = concept c
    ## Liveness/readiness for /api/health (port of refresh_loop monitor).
    c.healthy() is bool
    c.status() is string

  RateLimiter* = concept c
    ## Sliding-window per-key rate limiting (port of rate_limiter.cr).
    c.check("k") is RateLimitResult

  ProxyValidator* = concept c
    ## SSRF-safe URL validation for the image proxy (port of
    ## api_base_controller validate_proxy_url).
    c.validate("https://x/img.png") is ProxyValidateResult

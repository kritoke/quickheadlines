## App composition root (design D3).
##
## Every long-lived dependency is held as a field of `App` and passed into
## handlers/supervisors as a parameter. No module-level mutable state. The
## generic `App[F,C,FS,...]` is parameterised by the concrete concept-satisfying
## impls, so the same App shell works for production (real impls) and for tests
## (in-memory impls). Constructed once in main.nim (Phase 3).

import ./concepts

type
  App*[F, C, FS, IS, CS, B, CF, H, R, P] = ref object
    ## Composition root. Type params are the black-box boundaries:
    ## F=Fetcher, C=Clusterer, FS=FeedStore, IS=ItemStore, CS=ClusterStore,
    ## B=Broadcaster, CF=ConfigSource, H=HealthReporter, R=RateLimiter,
    ## P=ProxyValidator.
    fetcher*: F
    clusterer*: C
    feedStore*: FS
    itemStore*: IS
    clusterStore*: CS
    broadcaster*: B
    configSource*: CF
    health*: H
    rateLimiter*: R
    proxyValidator*: P

  ## Bound checks: constructing an App is only legal if every field satisfies
  ## its concept. Compile-time proof lives in tests/test_concept_checks.nim.

template requireFetcher*[F](f: F): void =
  static: doAssert F is Fetcher, "App.fetcher must satisfy Fetcher"
template requireClusterer*[C](c: C): void =
  static: doAssert C is Clusterer, "App.clusterer must satisfy Clusterer"
template requireFeedStore*[FS](s: FS): void =
  static: doAssert FS is FeedStore, "App.feedStore must satisfy FeedStore"
template requireItemStore*[IS](s: IS): void =
  static: doAssert IS is ItemStore, "App.itemStore must satisfy ItemStore"
template requireClusterStore*[CS](s: CS): void =
  static: doAssert CS is ClusterStore, "App.clusterStore must satisfy ClusterStore"
template requireBroadcaster*[B](b: B): void =
  static: doAssert B is Broadcaster, "App.broadcaster must satisfy Broadcaster"
template requireConfigSource*[CF](c: CF): void =
  static: doAssert CF is ConfigSource, "App.configSource must satisfy ConfigSource"
template requireHealth*[H](h: H): void =
  static: doAssert H is HealthReporter, "App.health must satisfy HealthReporter"
template requireRateLimiter*[R](r: R): void =
  static: doAssert R is RateLimiter, "App.rateLimiter must satisfy RateLimiter"
template requireProxyValidator*[P](p: P): void =
  static: doAssert P is ProxyValidator, "App.proxyValidator must satisfy ProxyValidator"

proc newApp*[F, C, FS, IS, CS, B, CF, H, R, P](
    fetcher: F, clusterer: C, feedStore: FS, itemStore: IS, clusterStore: CS,
    broadcaster: B, configSource: CF, health: H, rateLimiter: R,
    proxyValidator: P): App[F, C, FS, IS, CS, B, CF, H, R, P] =
  ## Build the App. Each template below emits a compile-time concept check, so
  ## a type that does NOT satisfy its boundary fails to compile here.
  requireFetcher(fetcher)
  requireClusterer(clusterer)
  requireFeedStore(feedStore)
  requireItemStore(itemStore)
  requireClusterStore(clusterStore)
  requireBroadcaster(broadcaster)
  requireConfigSource(configSource)
  requireHealth(health)
  requireRateLimiter(rateLimiter)
  requireProxyValidator(proxyValidator)
  App[F, C, FS, IS, CS, B, CF, H, R, P](
    fetcher: fetcher, clusterer: clusterer, feedStore: feedStore,
    itemStore: itemStore, clusterStore: clusterStore, broadcaster: broadcaster,
    configSource: configSource, health: health, rateLimiter: rateLimiter,
    proxyValidator: proxyValidator)

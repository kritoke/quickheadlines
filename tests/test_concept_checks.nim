## Phase-2 contract enforcement (design spec nim-black-box-boundaries).
##
## Every `static: doAssert(X is Concept)` here is a COMPILE-TIME proof that the
## in-memory impl matches its black-box boundary. If any impl drifts from its
## concept, this file fails to compile - exactly the enforcement the spec
## requires ("Production impl matches concept -> build fails").
##
## Run: nim c -r tests/test_concept_checks.nim   (or `nimble test`)

import std/[tables, unittest]
import ../src/qh/types
import ../src/qh/concepts
import ../src/qh/app
import ../src/qh/in_memory/stores
import ../src/qh/in_memory/fetcher_clusterer
import ../src/qh/in_memory/services

# ---- compile-time: every in-memory impl satisfies its boundary concept
static:
  doAssert InMemoryFetcher is Fetcher,         "InMemoryFetcher must satisfy Fetcher"
  doAssert InMemoryClusterer is Clusterer,      "InMemoryClusterer must satisfy Clusterer"
  doAssert InMemoryFeedStore is FeedStore,      "InMemoryFeedStore must satisfy FeedStore"
  doAssert InMemoryItemStore is ItemStore,      "InMemoryItemStore must satisfy ItemStore"
  doAssert InMemoryClusterStore is ClusterStore,"InMemoryClusterStore must satisfy ClusterStore"
  doAssert InMemoryBroadcaster is Broadcaster,  "InMemoryBroadcaster must satisfy Broadcaster"
  doAssert InMemoryConfigSource is ConfigSource,"InMemoryConfigSource must satisfy ConfigSource"
  doAssert InMemoryHealthReporter is HealthReporter
  doAssert InMemoryRateLimiter is RateLimiter
  doAssert InMemoryProxyValidator is ProxyValidator

suite "in-memory boundaries":

  test "Fetcher returns canned data":
    let f = InMemoryFetcher(canned: {
      "https://x": FeedData(title: "X", url: "https://x")
    }.toTable)
    check f.fetch("https://x").isOk
    check f.fetch("https://x").data.title == "X"
    check f.fetch("https://missing").isOk == false

  test "Clusterer groups similar, skips same-feed":
    let c = InMemoryClusterer(threshold: 0.5)
    let items = @[
      ClusteringItem(id: 1, title: "apple macbook m4", feedId: 1, feedUrl: "a.com"),
      ClusteringItem(id: 2, title: "apple macbook m4", feedId: 2, feedUrl: "b.com"),
      ClusteringItem(id: 3, title: "nasa artemis moon", feedId: 3, feedUrl: "c.com"),
    ]
    let r = c.cluster(items)
    check r.isOk
    check r.clusters[1].len == 2          # 1 & 2 cluster; 3 singleton
    check 3 notin r.clusters

  test "FeedStore upsert + list":
    let s = InMemoryFeedStore()
    discard s.upsertFeed(FeedRow(id: 1, url: "https://a", title: "A"))
    discard s.upsertFeed(FeedRow(id: 2, url: "https://b", title: "B"))
    let listed = s.listFeeds()
    check listed.isOk and listed.feeds.len == 2

  test "ItemStore timeline slice + total":
    var es: seq[TimelineEntry]
    for i in 1..10: es.add TimelineEntry(id: i.int64, title: "t" & $i)
    let s = InMemoryItemStore(entries: es)
    let r = s.findTimeline(limit = 3, offset = 0, daysBack = 14)
    check r.isOk and r.entries.len == 3 and r.total == 10

  test "App composes all in-memory boundaries":
    let app = newApp(
      InMemoryFetcher(),
      InMemoryClusterer(threshold: 0.5),
      InMemoryFeedStore(),
      InMemoryItemStore(),
      InMemoryClusterStore(),
      InMemoryBroadcaster(subscribers: 1),
      InMemoryConfigSource(config: Config(pageTitle: "QH", itemLimit: 20)),
      InMemoryHealthReporter(healthyFlag: true, detail: "feeds=0"),
      InMemoryRateLimiter(budget: 5),
      InMemoryProxyValidator(),
    )
    check app.configSource.load().isOk
    check app.health.healthy()
    check app.rateLimiter.check("1.2.3.4").isOk
    check app.proxyValidator.validate("https://img/x.png").isOk
    check app.broadcaster.broadcast("{}").isOk

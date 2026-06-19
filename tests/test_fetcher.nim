## P3.4 production Fetcher test. Proves the concept, retries, concurrent pool,
## and end-to-end refresh -> SQLite persistence against real feeds.
## Run: nim c --threads:on -r tests/test_fetcher.nim

import std/[unittest, os, options]
import tiny_sqlite
import ../src/qh/types
import ../src/qh/concepts
import ../src/qh/storage/[database, feed_store]
import ../src/qh/fetcher/[http_fetcher, fetch_pipeline]

static:
  doAssert(HttpFetcher is Fetcher)

suite "production fetcher (P3.4)":
  test "fetch one real feed":
    let f = newHttpFetcher(maxRetries = 1)
    let r = f.fetch("https://news.ycombinator.com/rss")
    check r.isOk
    check r.data.items.len > 0
    check r.data.title.len > 0

  test "retry: malformed url is feNetwork/feHttp, not a crash":
    let f = newHttpFetcher(maxRetries = 1)
    let r = f.fetch("https://this-host-does-not-exist.invalid.invalid/rss")
    check not r.isOk
    check r.err in {feNetwork, feHttp}

  test "concurrent refresh persists to SQLite":
    let path = getTempDir() / "qh_nim_fetcher.db"
    removeFile(path)
    let db = openAndCreate(path)
    defer:
      db.close()
      removeFile(path); removeFile(path & "-wal"); removeFile(path & "-shm")
    let store = SqliteFeedStore(db: db)
    let f = newHttpFetcher(maxRetries = 1)
    let summary = f.refreshAll(@[
      FeedConfig(url: "https://news.ycombinator.com/rss", title: "Hacker News"),
      FeedConfig(url: "https://feeds.arstechnica.com/arstechnica/index", title: "Ars Technica"),
    ], store, maxConcurrency = 4)
    check summary.fetched >= 1               # at least one feed succeeded
    let listed = store.listFeeds()
    check listed.isOk
    check listed.feeds.len >= 1
    let itemCount = db.one("SELECT COUNT(*) FROM items").get[0].intVal
    check itemCount > 0
    echo "  refresh summary: fetched=", summary.fetched, " failed=", summary.failed, " items=", summary.items

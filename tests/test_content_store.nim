## Content store tests - verifies article_content table + CRUD operations.
## Run: nim c -d:ssl --threads:on -r tests/test_content_store.nim

import std/[unittest, os, strutils]
import tiny_sqlite
import ../src/qh/storage/[database, content_store]

suite "content store (P3.7b)":
  setup:
    let db = openDatabase(":memory:")
    db.createSchema(":memory:")
    let store = SqliteContentStore(db: db)

  teardown:
    db.close()

  test "store and retrieve content":
    check store.storeContent("http://example.com/article1", "http://example.com/feed", "Test Title", "<p>Hello world</p>")
    let content = store.getContent("http://example.com/article1")
    check content == "<p>Hello world</p>"

  test "getArticle returns full metadata":
    discard store.storeContent("http://example.com/art2", "http://example.com/feed", "Title 2", "Some content here")
    let art = store.getArticle("http://example.com/art2")
    check art.link == "http://example.com/art2"
    check art.feedUrl == "http://example.com/feed"
    check art.title == "Title 2"
    check art.content == "Some content here"
    check art.contentType == "html"

  test "getArticle returns empty for missing link":
    let art = store.getArticle("http://nonexistent.com/article")
    check art.link.len == 0

  test "storeContent skips empty content":
    check store.storeContent("http://example.com/empty", "http://example.com/feed", "Title", "") == false
    check store.getContent("http://example.com/empty") == ""

  test "storeContent upserts on conflict":
    discard store.storeContent("http://example.com/same", "http://example.com/feed", "V1", "Content v1")
    discard store.storeContent("http://example.com/same", "http://example.com/feed", "V2", "Content v2")
    check store.getContent("http://example.com/same") == "Content v2"

  test "contentCount":
    check store.contentCount() == 0
    discard store.storeContent("http://a.com/1", "http://a.com/f", "T1", "C1")
    discard store.storeContent("http://a.com/2", "http://a.com/f", "T2", "C2")
    check store.contentCount() == 2

  test "cleanupOldEntries":
    # Insert with old timestamp
    store.db.exec("""INSERT INTO article_content (item_link, feed_url, title, content, content_type, fetched_at, created_at)
      VALUES ('http://old.com/1', 'http://old.com/f', 'Old', 'Old content', 'html', '2020-01-01 00:00:00', '2020-01-01 00:00:00')""")
    discard store.storeContent("http://new.com/1", "http://new.com/f", "New", "New content")
    check store.contentCount() == 2
    let cleaned = store.cleanupOldEntries(30)  # 30 days retention
    check cleaned == 1
    check store.contentCount() == 1

  test "isSummaryOnly detects short content":
    check isSummaryOnly("") == true
    check isSummaryOnly("short") == true
    let longContent = "This is a real article paragraph with enough content to not be considered a summary by the heuristic. It has multiple sentences that provide meaningful information about the topic at hand and should pass all the quality checks.\n\nThis is a second paragraph that adds more depth to the article content and ensures we have enough structural complexity to not trigger the summary detection heuristic."
    check isSummaryOnly(longContent) == false

  test "isSummaryOnly detects summary patterns":
    check isSummaryOnly("This is a preview. Read more to continue.") == true
    check isSummaryOnly("Subscribe to our newsletter for more content and updates.") == true
    check isSummaryOnly("Click here to read the full article on our website.") == true

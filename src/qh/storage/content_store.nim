## Article content store — port of Crystal Azurite::Store + ContentService.
## Stores full article content from RSS/Atom entries for the reader mode
## endpoint (/api/content). Uses the same SQLite database as feeds/items
## (article_content table, migration 11).

import std/[times, strutils, re]
import tiny_sqlite
import ./database  # dbStr

const
  MaxContentBytes* = 1_048_576   # 1MB per article
  MinContentLength* = 200        # below this = summary-only
  MaxDbSizeMb* = 100             # hard limit
  RetentionDays* = 45

type
  ArticleContent* = object
    link*: string
    feedUrl*: string
    title*: string
    content*: string
    contentType*: string
    fetchedAt*: string

  SqliteContentStore* = ref object
    db*: DbConn

proc nowUtcStr(): string = now().utc().format("yyyy-MM-dd HH:mm:ss")

proc isSummaryOnly*(content: string): bool =
  ## Port of Crystal summary_only_content? heuristic.
  ## Returns true if content is too short or matches summary patterns.
  if content.len == 0: return true
  if content.len < MinContentLength: return true
  let lower = content.toLowerAscii()
  for pat in ["read more", "read full article", "subscribe to",
              "click here", "sorry, this content", "content is not available",
              "log in to read"]:
    if pat in lower: return true
  # Fewer than 2 paragraphs AND short → summary
  let paragraphs = content.split(re"\n\n+")
  if paragraphs.len < 2 and content.len < 400: return true
  false

proc storeContent*(s: SqliteContentStore; itemLink, feedUrl, title, content: string): bool =
  ## Store article content. Returns true on success. Skips if too large.
  if content.len == 0 or content.len > MaxContentBytes: return false
  try:
    s.db.exec("""
      INSERT INTO article_content (item_link, feed_url, title, content, content_type, fetched_at)
      VALUES (?, ?, ?, ?, 'html', ?)
      ON CONFLICT(item_link) DO UPDATE SET
        content=excluded.content, title=excluded.title,
        feed_url=excluded.feed_url, fetched_at=excluded.fetched_at""",
      itemLink, feedUrl, title, content, nowUtcStr())
    true
  except CatchableError:
    false

proc getContent*(s: SqliteContentStore; itemLink: string): string =
  ## Get content string for an item link. Returns "" if not found.
  let r = s.db.one("SELECT content FROM article_content WHERE item_link = ?", itemLink)
  if r.isSome: r.get[0].dbStr else: ""

proc getArticle*(s: SqliteContentStore; itemLink: string): ArticleContent =
  ## Get full article metadata for an item link. Returns empty ArticleContent if not found.
  let r = s.db.one("""
    SELECT item_link, feed_url, title, content, content_type, fetched_at
    FROM article_content WHERE item_link = ?""", itemLink)
  if r.isSome:
    let row = r.get
    ArticleContent(
      link: row[0].dbStr, feedUrl: row[1].dbStr, title: row[2].dbStr,
      content: row[3].dbStr, contentType: row[4].dbStr, fetchedAt: row[5].dbStr)
  else:
    ArticleContent()

proc cleanupOldEntries*(s: SqliteContentStore; retentionDays = RetentionDays): int =
  ## Delete entries older than retentionDays. Returns count deleted.
  try:
    let before = s.db.one("SELECT COUNT(*) FROM article_content").get[0].intVal
    s.db.exec("DELETE FROM article_content WHERE created_at < datetime('now', '-' || ? || ' days')", retentionDays)
    let after = s.db.one("SELECT COUNT(*) FROM article_content").get[0].intVal
    (before - after).int
  except CatchableError:
    0

proc cleanupLowQuality*(s: SqliteContentStore; minLength = MinContentLength): int =
  ## Delete entries with content shorter than minLength. Returns count deleted.
  try:
    let before = s.db.one("SELECT COUNT(*) FROM article_content").get[0].intVal
    s.db.exec("DELETE FROM article_content WHERE LENGTH(content) < ?", minLength)
    let after = s.db.one("SELECT COUNT(*) FROM article_content").get[0].intVal
    (before - after).int
  except CatchableError:
    0

proc contentCount*(s: SqliteContentStore): int =
  let r = s.db.one("SELECT COUNT(*) FROM article_content")
  if r.isSome: r.get[0].intVal.int else: 0

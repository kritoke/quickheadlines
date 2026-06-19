## P3.2 schema + migrations test. Creates a fresh in-memory DB, runs the full
## schema/migration pipeline, and verifies the result is byte-shape-compatible
## with the Crystal backend (tables, post-migration columns, schema version=10).
## Run: nim c -r tests/test_storage.nim

import std/[unittest, os, sets, options]
import tiny_sqlite
import ../src/qh/storage/database

proc tableNames(db: DbConn): HashSet[string] =
  for r in db.all("SELECT name FROM sqlite_master WHERE type='table'"):
    result.incl r[0].dbStr

proc columnsOf(db: DbConn; table: string): HashSet[string] =
  for r in db.all("SELECT name FROM pragma_table_info('" & table & "')"):
    result.incl r[0].dbStr

proc indexNames(db: DbConn): HashSet[string] =
  for r in db.all("SELECT name FROM sqlite_master WHERE type='index'"):
    result.incl r[0].dbStr

proc schemaVersion(db: DbConn): string =
  let r = db.one("SELECT version FROM schema_info LIMIT 1")
  if r.isSome: r.get[0].dbStr else: ""

suite "schema + migrations (P3.2)":
  test "in-memory: all tables created":
    let db = openDatabase(":memory:")
    defer: db.close()
    db.createSchema(":memory:")
    let t = db.tableNames()
    check t.contains("feeds")
    check t.contains("items")
    check t.contains("lsh_bands")
    check t.contains("schema_info")

  test "all migrations applied (version = 10)":
    let db = openDatabase(":memory:")
    defer: db.close()
    db.createSchema(":memory:")
    check db.schemaVersion() == "10"

  test "post-migration columns present on items":
    let db = openDatabase(":memory:")
    defer: db.close()
    db.createSchema(":memory:")
    let c = db.columnsOf("items")
    for col in ["id","feed_id","title","link","normalized_link","pub_date",
                "version","minhash_signature","cluster_id","comment_url",
                "commentary_url","date_normalized"]:
      check c.contains(col)

  test "feeds columns present":
    let db = openDatabase(":memory:")
    defer: db.close()
    db.createSchema(":memory:")
    let c = db.columnsOf("feeds")
    for col in ["id","url","title","site_link","header_color","favicon",
                "favicon_data","header_text_color","header_theme_colors",
                "etag","last_modified","last_fetched","created_at"]:
      check c.contains(col)

  test "all 11 indexes created":
    let db = openDatabase(":memory:")
    defer: db.close()
    db.createSchema(":memory:")
    let idx = db.indexNames()
    for n in ["idx_items_feed_id","idx_items_pub_date","idx_feeds_last_fetched",
              "idx_feeds_url","idx_items_cluster","idx_lsh_band_search",
              "idx_items_unique_feed_link","idx_items_link","idx_items_timeline",
              "idx_items_cluster_rep","idx_items_feed_timeline"]:
      check idx.contains(n)

  test "file DB: integrity ok + idempotent re-create":
    let path = getTempDir() / "qh_nim_test.db"
    removeFile(path)
    let db = openAndCreate(path)
    db.close()
    check integrityOk(path)
    let db2 = openDatabase(path)
    defer: db2.close()
    db2.createSchema(path)
    check db2.schemaVersion() == "10"
    removeFile(path)
    removeFile(path & "-wal")
    removeFile(path & "-shm")

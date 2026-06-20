## SQLite database init + migrations - port of src/storage/database.cr.
## Uses tiny_sqlite (the nix Nim 2.2.4 build omits stdlib db_sqlite, recorded
## as a Phase-3 finding). createSchema() produces a DB byte-compatible with
## the Crystal backend (same DDL, same migrations). This module is the only
## importer of tiny_sqlite (design D4: external dep behind a wrapper).

import std/[strutils, logging, options]
import tiny_sqlite
import ./schema

const
  SqliteBusyTimeoutMs* = 30000      # Constants::SQLITE_BUSY_TIMEOUT_MS
  WalAutocheckpointPages* = 1000    # Constants::WAL_AUTOCHECKPOINT_PAGES
  MinDbSizeBytes* = 100             # Constants::MIN_DB_SIZE_BYTES

proc dbStr*(v: DbValue): string =
  ## Stringify a single DbValue (kind-aware; DbValue is a variant).
  case v.kind
  of sqliteInteger: $v.intVal
  of sqliteText: v.strVal
  of sqliteReal: $v.floatVal
  else: ""

proc scalarStr(db: DbConn; q: string; args: varargs[DbValue, toDbValue]): string =
  let r = db.one(q, args)
  if r.isSome: r.get[0].dbStr else: ""

proc columnExists(db: DbConn; table, column: string): bool =
  try:
    db.scalarStr("SELECT 1 FROM pragma_table_info(?) WHERE name = ?", table, column) == "1"
  except CatchableError:
    false

proc ensureColumn(db: DbConn; table, column, colType: string) =
  if not db.columnExists(table, column):
    db.exec("ALTER TABLE " & table & " ADD COLUMN " & column & " " & colType)

# ---------------------------------------------------------------- migrations (verbatim from database.cr)

type Migration = object
  version: int
  name: string
  up: proc(db: DbConn)

proc migrations(): seq[Migration] =
  ## The 10 Crystal migrations, in order. ensureColumn makes them idempotent.
  @[
    Migration(version: 1, name: "add_favicon_data_column",
      up: proc(db: DbConn) = db.ensureColumn("feeds", "favicon_data", "TEXT")),
    Migration(version: 2, name: "add_header_text_color_column",
      up: proc(db: DbConn) = db.ensureColumn("feeds", "header_text_color", "TEXT")),
    Migration(version: 3, name: "add_header_theme_colors_column",
      up: proc(db: DbConn) = db.ensureColumn("feeds", "header_theme_colors", "TEXT")),
    Migration(version: 4, name: "add_minhash_signature_column",
      up: proc(db: DbConn) = db.ensureColumn("items", "minhash_signature", "BLOB")),
    Migration(version: 5, name: "add_cluster_id_column",
      up: proc(db: DbConn) = db.ensureColumn("items", "cluster_id", "INTEGER REFERENCES items(id)")),
    Migration(version: 6, name: "migrate_lsh_bands_to_text",
      up: proc(db: DbConn) =
        let raw = db.scalarStr("SELECT band_hash FROM lsh_bands LIMIT 1")
        if raw.len > 0 and raw.parseInt() > 0:
          db.exec("DROP TABLE lsh_bands")),
    Migration(version: 7, name: "add_comment_url_and_commentary_url_columns",
      up: proc(db: DbConn) =
        db.ensureColumn("items", "comment_url", "TEXT")
        db.ensureColumn("items", "commentary_url", "TEXT")),
    Migration(version: 8, name: "drop_position_column",
      up: proc(db: DbConn) =
        if db.columnExists("items", "position"):
          db.exec("ALTER TABLE items DROP COLUMN position")),
    Migration(version: 9, name: "add_date_normalized_column",
      up: proc(db: DbConn) = db.ensureColumn("items", "date_normalized", "INTEGER NOT NULL DEFAULT 0")),
    Migration(version: 10, name: "add_normalized_link_column",
      up: proc(db: DbConn) =
        db.ensureColumn("items", "normalized_link", "TEXT NOT NULL DEFAULT ''")
        db.exec("UPDATE items SET normalized_link = link")
        db.exec("DROP INDEX IF EXISTS idx_items_unique_feed_link")
        db.exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_items_unique_feed_link ON items(feed_id, normalized_link)")),
  ]

proc ensureSchemaInfoTable(db: DbConn) =
  db.exec("CREATE TABLE IF NOT EXISTS schema_info (version INTEGER PRIMARY KEY)")
  if db.scalarStr("SELECT version FROM schema_info LIMIT 1").len == 0:
    db.exec("INSERT INTO schema_info (version) VALUES (0)")

proc getSchemaVersion(db: DbConn): int =
  let v = db.scalarStr("SELECT version FROM schema_info LIMIT 1")
  if v.len == 0: 0 else: v.parseInt()

proc setSchemaVersion(db: DbConn; version: int) =
  db.exec("UPDATE schema_info SET version = ?", version)

proc runMigrations*(db: DbConn) =
  ## Apply all migrations with version > current, in order.
  db.ensureSchemaInfoTable()
  let current = db.getSchemaVersion()
  for m in migrations():
    if m.version <= current: continue
    info "Running migration ", m.version, ": ", m.name
    m.up(db)
    db.setSchemaVersion(m.version)

proc createSchema*(db: DbConn; dbPath: string) =
  ## Create the full schema + indexes + run migrations + dup-item cleanup.
  ## Port of Database.create_schema.
  db.exec("PRAGMA journal_mode = WAL")
  db.exec("PRAGMA synchronous = NORMAL")
  db.exec("PRAGMA cache_size = -16000")
  db.exec("PRAGMA foreign_keys = ON")
  db.exec("PRAGMA wal_autocheckpoint = " & $WalAutocheckpointPages)
  db.exec("PRAGMA busy_timeout = " & $SqliteBusyTimeoutMs)
  db.exec("PRAGMA temp_store = MEMORY")
  db.exec("PRAGMA mmap_size = 4294967296")

  db.exec(FeedsTable)
  db.exec(ItemsTable)
  db.exec(LshBandsTable)
  for idx in Indexes: db.exec(idx)

  db.runMigrations()

  # Dedup items (port of the cleanup transaction in create_schema).
  db.exec("""
    DELETE FROM items
    WHERE id NOT IN (
      SELECT MAX(id) FROM items GROUP BY feed_id, normalized_link
    )""")

proc openAndCreate*(dbPath: string): DbConn =
  ## Open (or create) the SQLite file and initialise the schema. Caller owns
  ## the DbConn and must close() it.
  result = openDatabase(dbPath)
  result.createSchema(dbPath)

proc closeDb*(db: DbConn) {.inline.} =
  ## Close a DbConn (tiny_sqlite wrapper; keeps the close call in storage/).
  db.close()

proc integrityOk*(dbPath: string): bool =
  ## PRAGMA integrity_check == "ok".
  let db = openDatabase(dbPath)
  try: result = db.scalarStr("PRAGMA integrity_check") == "ok"
  finally: db.close()

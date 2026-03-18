module Schema
  FEEDS_TABLE = <<-SQL
    CREATE TABLE IF NOT EXISTS feeds (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      url TEXT UNIQUE NOT NULL,
      title TEXT NOT NULL,
      site_link TEXT,
      header_color TEXT,
      header_theme_colors TEXT,
      header_text_color TEXT,
      etag TEXT,
      last_modified TEXT,
      favicon TEXT,
      favicon_data TEXT,
      last_fetched TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    SQL

  ITEMS_TABLE = <<-SQL
    CREATE TABLE IF NOT EXISTS items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      feed_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      link TEXT NOT NULL,
      pub_date TEXT,
      version TEXT,
      comment_url TEXT,
      commentary_url TEXT,
      is_discussion_url INTEGER DEFAULT 0,
      position INTEGER NOT NULL,
      minhash_signature BLOB,
      cluster_id INTEGER REFERENCES items(id),
      FOREIGN KEY (feed_id) REFERENCES feeds(id) ON DELETE CASCADE,
      UNIQUE(feed_id, link)
    )
    SQL

  LSH_BANDS_TABLE = <<-SQL
    CREATE TABLE IF NOT EXISTS lsh_bands (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL,
      band_index INTEGER NOT NULL,
      band_hash TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
      UNIQUE(item_id, band_index)
    )
    SQL

  INDEXES = <<-SQL
    CREATE INDEX IF NOT EXISTS idx_items_feed_id ON items(feed_id);
    CREATE INDEX IF NOT EXISTS idx_items_pub_date ON items(pub_date DESC);
    CREATE INDEX IF NOT EXISTS idx_feeds_last_fetched ON feeds(last_fetched DESC);
    CREATE INDEX IF NOT EXISTS idx_feeds_url ON feeds(url);
    CREATE INDEX IF NOT EXISTS idx_items_cluster ON items(cluster_id);
    CREATE INDEX IF NOT EXISTS idx_lsh_band_search ON lsh_bands(band_index, band_hash);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_items_unique_feed_link ON items(feed_id, link);
    SQL
end

require "db"
require "time"
require "../services/clustering_service"

module ClusteringRepository
  def find_all_items_excluding(item_id : Int64, limit : Int32 = 500) : Array(Int64)
    items = [] of Int64
    @mutex.synchronize do
      @db.query("SELECT id FROM items WHERE id != ? ORDER BY id DESC LIMIT ?", item_id, limit) do |rows|
        rows.each do
          items << rows.read(Int64)
        end
      end
    end
    items
  end

  def find_by_keywords(keywords : Array(String), exclude_id : Int64, limit : Int32 = 100) : Array(Int64)
    return [] of Int64 if keywords.empty?

    items = [] of Int64
    placeholders = keywords.map { |_| "title LIKE ?" }.join(" OR ")
    sql = "SELECT DISTINCT id FROM items WHERE id != ? AND (#{placeholders}) ORDER BY id DESC LIMIT ?"

    args = [exclude_id] + keywords.map { |k| "%#{k}%" } + [limit]
    @db.query(sql, args: args) do |rows|
      rows.each do
        items << rows.read(Int64)
      end
    end
    items
  end

  def assign_cluster(item_id : Int64, cluster_id : Int64?)
    @db.exec("UPDATE items SET cluster_id = ? WHERE id = ?", cluster_id, item_id)
  end

  def store_item_signature(item_id : Int64, signature : Array(UInt32))
    @mutex.synchronize do
      bytes = LexisMinhash::Engine.signature_to_bytes(signature)
      @db.exec("UPDATE items SET minhash_signature = ? WHERE id = ?", bytes, item_id)
    end
  end

  def get_item_signature(item_id : Int64) : Array(UInt32)?
    @mutex.synchronize do
      result = @db.query_one?("SELECT minhash_signature FROM items WHERE id = ?", item_id, as: {Bytes?})
      return unless result
      LexisMinhash::Engine.bytes_to_signature(result)
    end
  end

  def store_lsh_bands(item_id : Int64, band_hashes : Array(UInt64))
    @mutex.synchronize do
      begin
        @db.exec("BEGIN TRANSACTION")
        @db.exec("DELETE FROM lsh_bands WHERE item_id = ?", item_id)
        band_hashes.each_with_index do |band_hash, band_index|
          @db.exec(
            "INSERT INTO lsh_bands (item_id, band_index, band_hash, created_at) VALUES (?, ?, ?, ?)",
            item_id,
            band_index,
            band_hash.to_i64,
            Time.utc.to_s("%Y-%m-%d %H:%M:%S")
          )
        end
        @db.exec("COMMIT")
      rescue ex
        @db.exec("ROLLBACK")
        STDERR.puts "[Cache ERROR] Failed to store LSH bands for item #{item_id}: #{ex.message}"
      end
    end
  end

  def find_lsh_candidates(signature : Array(UInt32)) : Array(Int64)
    bands = LexisMinhash::Engine.generate_bands(signature)
    candidates = Set(Int64).new

    @mutex.synchronize do
      bands.each do |band_index, band_hash|
        @db.query("SELECT DISTINCT item_id FROM lsh_bands WHERE band_index = ? AND band_hash = ?", band_index, band_hash.to_i64) do |rows|
          rows.each do
            item_id = rows.read(Int64)
            candidates << item_id
          end
        end
      end
    end

    candidates.to_a
  end

  def clear_clustering_metadata
    @mutex.synchronize do
      @db.exec("UPDATE items SET cluster_id = NULL")
      @db.exec("DELETE FROM lsh_bands")
      STDERR.puts "[#{Time.local}] Cleared clustering metadata"
    end
  end

  def get_cluster_items(cluster_id : Int64) : Array(Int64)
    items = [] of Int64
    @mutex.synchronize do
      @db.query("SELECT id FROM items WHERE cluster_id = ? ORDER BY id ASC", cluster_id) do |rows|
        rows.each do
          items << rows.read(Int64)
        end
      end
    end
    items
  end

  def get_cluster_size(item_id : Int64) : Int32
    @mutex.synchronize do
      result = @db.query_one?(
        "SELECT COUNT(*) FROM items WHERE cluster_id = (SELECT cluster_id FROM items WHERE id = ?)",
        item_id,
        as: {Int64}
      )
      result ? result.to_i : 1
    end
  end

  def cluster_representative?(item_id : Int64) : Bool
    @mutex.synchronize do
      cluster_id = @db.query_one?("SELECT cluster_id FROM items WHERE id = ?", item_id, as: {Int64?})
      return true unless cluster_id

      min_id = @db.query_one?(
        "SELECT MIN(id) FROM items WHERE cluster_id = ?",
        cluster_id,
        as: {Int64}
      )
      min_id == item_id
    end
  end

  def get_item_id(feed_url : String, item_link : String) : Int64?
    @mutex.synchronize do
      @db.query_one?(
        "SELECT items.id FROM items JOIN feeds ON items.feed_id = feeds.id WHERE feeds.url = ? AND items.link = ?",
        feed_url,
        item_link,
        as: {Int64}
      )
    end
  end

  def get_item_title(item_id : Int64) : String?
    @mutex.synchronize do
      @db.query_one?(
        "SELECT title FROM items WHERE id = ?",
        item_id,
        as: String
      )
    end
  end

  def get_item_feed_id(item_id : Int64) : Int64?
    @mutex.synchronize do
      @db.query_one?(
        "SELECT feed_id FROM items WHERE id = ?",
        item_id,
        as: Int64
      )
    end
  end

  def get_feed_id(feed_url : String) : Int64?
    @mutex.synchronize do
      @db.query_one?(
        "SELECT id FROM feeds WHERE url = ?",
        feed_url,
        as: Int64
      )
    end
  end

  def get_recent_items_for_clustering(hours_back : Int32 = 24, max_items : Int32 = 1000) : Array({id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?})
    @mutex.synchronize do
      cutoff = (Time.utc - hours_back.hours).to_s("%Y-%m-%d %H:%M:%S")

      items = [] of {id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?}

      query = <<-SQL
        SELECT i.id, i.title, i.link, i.pub_date, f.url as feed_url, f.title as feed_title, f.favicon, f.header_color
        FROM items i
        JOIN feeds f ON i.feed_id = f.id
        WHERE i.pub_date >= ? AND i.pub_date <= datetime('now', '+1 day')
        ORDER BY i.pub_date DESC
        LIMIT ?
        SQL

      @db.query(query, cutoff, max_items) do |rows|
        rows.each do
          id = rows.read(Int64)
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          feed_url = rows.read(String)
          feed_title = rows.read(String)
          favicon = rows.read(String?)
          header_color = rows.read(String?)

          pub_date = pub_date_str.try { |date_str| Time.parse(date_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

          items << {
            id:           id,
            title:        title,
            link:         link,
            pub_date:     pub_date,
            feed_url:     feed_url,
            feed_title:   feed_title,
            favicon:      favicon,
            header_color: header_color,
          }
        end
      end

      items
    end
  end

  def get_all_clusters : Array({id: Int64, representative_id: Int64, item_count: Int32})
    @mutex.synchronize do
      clusters = [] of {id: Int64, representative_id: Int64, item_count: Int32}

      query = <<-SQL
        SELECT c.id, MIN(c.representative_id) as representative_id, COUNT(*) as item_count
        FROM (
          SELECT cluster_id as id, MIN(id) as representative_id
          FROM items
          WHERE cluster_id IS NOT NULL
          GROUP BY cluster_id
        ) c
        JOIN items i ON i.cluster_id = c.id
        GROUP BY c.id
        ORDER BY MIN(i.pub_date) DESC
        SQL

      @db.query(query) do |rows|
        rows.each do
          cluster_id = rows.read(Int64)
          representative_id = rows.read(Int64)
          item_count = rows.read(Int64).to_i32
          clusters << {id: cluster_id, representative_id: representative_id, item_count: item_count}
        end
      end

      clusters
    end
  end

  def get_cluster_items_full(cluster_id : Int64) : Array({id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?})
    @mutex.synchronize do
      items = [] of {id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?}

      query = <<-SQL
        SELECT i.id, i.title, i.link, i.pub_date, f.url as feed_url, f.title as feed_title, f.favicon, f.header_color
        FROM items i
        JOIN feeds f ON i.feed_id = f.id
        WHERE i.cluster_id = ?
        ORDER BY i.id ASC
        SQL

      @db.query(query, cluster_id) do |rows|
        rows.each do
          id = rows.read(Int64)
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          feed_url = rows.read(String)
          feed_title = rows.read(String)
          favicon = rows.read(String?)
          header_color = rows.read(String?)

          pub_date = pub_date_str.try { |date_str| Time.parse(date_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

          items << {
            id:           id,
            title:        title,
            link:         link,
            pub_date:     pub_date,
            feed_url:     feed_url,
            feed_title:   feed_title,
            favicon:      favicon,
            header_color: header_color,
          }
        end
      end

      items
    end
  end
end

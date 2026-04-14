require "db"
require "mutex"
require "time"
require "../services/clustering_service"

module QuickHeadlines::Storage
  class ClusteringStore
    record ItemKey, feed_url : String, link : String
    record ClusterInfo, item_id : Int64, cluster_id : Int64?, cluster_size : Int32, is_representative : Bool

    MAX_LSH_CANDIDATES = 500

    def initialize(@db : DB::Database, @mutex : Mutex)
    end

    def other_item_ids(item_id : Int64, limit : Int32 = 500) : Array(Int64)
      items = [] of Int64
      @db.query("SELECT id FROM items WHERE id != ? ORDER BY id DESC LIMIT ?", item_id, limit) do |rows|
        rows.each do
          items << rows.read(Int64)
        end
      end
      items
    end

    def find_by_keywords(keywords : Array(String), exclude_id : Int64, limit : Int32 = 100) : Array(Int64)
      return [] of Int64 if keywords.empty?

      items = [] of Int64
      placeholders = keywords.map { |_| "title LIKE ?" }.join(" OR ")
      sql = "SELECT DISTINCT id FROM items WHERE id != ? AND (#{placeholders}) ORDER BY id DESC LIMIT ?"

      escaped_keywords = keywords.map { |k| "%#{escape_like_pattern(k)}%" }
      args = [exclude_id] + escaped_keywords + [limit]
      @db.query(sql, args: args) do |rows|
        rows.each do
          items << rows.read(Int64)
        end
      end
      items
    end

    private def escape_like_pattern(pattern : String) : String
      pattern.gsub("\\") { "\\\\" }
        .gsub("%") { "\\%" }
        .gsub("_") { "\\_" }
        .gsub("[") { "\\[" }
        .gsub("]") { "\\]" }
        .gsub("^") { "\\^" }
        .gsub("-") { "\\-" }
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
      result = @db.query_one?("SELECT minhash_signature FROM items WHERE id = ?", item_id, as: {Bytes?})
      return unless result
      LexisMinhash::Engine.bytes_to_signature(result)
    end

    def store_lsh_bands(item_id : Int64, band_hashes : Array(UInt64))
      @mutex.synchronize do
        @db.exec("BEGIN TRANSACTION")
        begin
          @db.exec("DELETE FROM lsh_bands WHERE item_id = ?", item_id)
          band_hashes.each_with_index do |band_hash, band_index|
            @db.exec(
              "INSERT INTO lsh_bands (item_id, band_index, band_hash, created_at) VALUES (?, ?, ?, ?)",
              item_id,
              band_index,
              band_hash.to_s(16),
              Time.utc.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)
            )
          end
          @db.exec("COMMIT")
        rescue ex
          @db.exec("ROLLBACK")
          Log.for("quickheadlines.storage").error(exception: ex) { "Failed to store LSH bands for item #{item_id}" }
          raise ex
        end
      end
    end

    def find_lsh_candidates(signature : Array(UInt32)) : Array(Int64)
      bands = LexisMinhash::Engine.generate_bands(signature)
      candidates = Set(Int64).new

      bands.each do |band_index, band_hash|
        @db.query("SELECT DISTINCT item_id FROM lsh_bands WHERE band_index = ? AND band_hash = ?", band_index, band_hash.to_s(16)) do |rows|
          rows.each do
            item_id = rows.read(Int64)
            candidates << item_id
            if candidates.size >= MAX_LSH_CANDIDATES
              return candidates.to_a
            end
          end
        end
      end

      candidates.to_a
    end

    def clear_clustering_metadata
      @mutex.synchronize do
        @db.transaction do
          @db.exec("UPDATE items SET cluster_id = NULL")
          @db.exec("DELETE FROM lsh_bands")
        end
        Log.for("quickheadlines.storage").info { "Cleared clustering metadata" }
      end
    end

    def assign_clusters_bulk(clusters : Hash(Int64, Array(Int64)))
      @mutex.synchronize do
        begin
          @db.exec("BEGIN TRANSACTION")
          clusters.each do |rep_id, members|
            next if members.empty?
            placeholders = members.map { |_| "?" }.join(",")
            sql = "UPDATE items SET cluster_id = ? WHERE id IN (#{placeholders})"
            args = [rep_id] + members
            @db.exec(sql, args: args)
          end
          @db.exec("COMMIT")
        rescue ex
          @db.exec("ROLLBACK")
          Log.for("quickheadlines.storage").error(exception: ex) { "Failed to assign clusters" }
          raise ex
        end
      end
    end

    def get_cluster_items(cluster_id : Int64) : Array(Int64)
      items = [] of Int64
      @db.query("SELECT id FROM items WHERE cluster_id = ? ORDER BY id ASC", cluster_id) do |rows|
        rows.each do
          items << rows.read(Int64)
        end
      end
      items
    end

    def get_cluster_size(item_id : Int64) : Int32
      result = @db.query_one?(
        "SELECT COUNT(*) FROM items WHERE cluster_id = (SELECT cluster_id FROM items WHERE id = ?)",
        item_id,
        as: {Int64}
      )
      result ? result.to_i : 1
    end

    def cluster_representative?(item_id : Int64) : Bool
      cluster_id = @db.query_one?("SELECT cluster_id FROM items WHERE id = ?", item_id, as: {Int64?})
      return true unless cluster_id

      min_id = @db.query_one?(
        "SELECT MIN(id) FROM items WHERE cluster_id = ?",
        cluster_id,
        as: {Int64}
      )
      min_id == item_id
    end

    def get_item_id(feed_url : String, item_link : String) : Int64?
      @db.query_one?(
        "SELECT items.id FROM items JOIN feeds ON items.feed_id = feeds.id WHERE feeds.url = ? AND items.link = ?",
        feed_url,
        item_link,
        as: {Int64}
      )
    end

    def get_item_ids_batch(items : Array(ItemKey)) : Hash(String, Int64)
      result = {} of String => Int64
      return result if items.empty?

      feed_urls = items.map(&.feed_url).uniq!
      feed_url_to_id = {} of String => Int64

      if !feed_urls.empty?
        placeholders = feed_urls.map { |_| "?" }.join(",")
        @db.query("SELECT url, id FROM feeds WHERE url IN (#{placeholders})", args: feed_urls) do |rows|
          rows.each do
            url = rows.read(String)
            id = rows.read(Int64)
            feed_url_to_id[url] = id
          end
        end
      end

      grouped = items.group_by { |item| feed_url_to_id[item.feed_url]? }
      grouped.each do |feed_id, grouped_items|
        next unless feed_id
        links = grouped_items.map(&.link)
        placeholders = links.map { |_| "?" }.join(",")
        query = "SELECT link, id FROM items WHERE feed_id = ? AND link IN (#{placeholders})"
        @db.query(query, [feed_id] + links) do |rows|
          rows.each do
            link = rows.read(String)
            id = rows.read(Int64)
            item_key = grouped_items.find { |item| item.link == link }
            if item_key
              result["#{item_key.feed_url}|#{link}"] = id
            end
          end
        end
      end
      result
    end

    def get_cluster_info_batch(item_ids : Array(Int64)) : Hash(Int64, ClusterInfo)
      result = {} of Int64 => ClusterInfo
      return result if item_ids.empty?

      placeholders = item_ids.map { |_| "?" }.join(",")
      query = <<-SQL
        WITH cluster_info AS (
          SELECT
            cluster_id,
            MIN(id) as representative_id,
            COUNT(*) as cluster_size
          FROM items
          WHERE cluster_id IS NOT NULL
          GROUP BY cluster_id
        )
        SELECT
          i.id,
          i.cluster_id,
          COALESCE(ci.cluster_size, 0) as cluster_size,
          CASE WHEN i.cluster_id IS NULL OR i.id = ci.representative_id THEN 1 ELSE 0 END as is_representative
        FROM items i
        LEFT JOIN cluster_info ci ON i.cluster_id = ci.cluster_id
        WHERE i.id IN (#{placeholders})
        SQL

      @db.query(query, item_ids) do |rows|
        rows.each do
          id = rows.read(Int64)
          cluster_id = rows.read(Int64?)
          cluster_size = rows.read(Int32)
          is_rep = rows.read(Int32) == 1
          result[id] = ClusterInfo.new(id, cluster_id, cluster_size, is_rep)
        end
      end
      result
    end

    def get_item_title(item_id : Int64) : String?
      @db.query_one?(
        "SELECT title FROM items WHERE id = ?",
        item_id,
        as: String
      )
    end

    def get_item_feed_id(item_id : Int64) : Int64?
      @db.query_one?(
        "SELECT feed_id FROM items WHERE id = ?",
        item_id,
        as: Int64?
      )
    end

    def get_feed_id(feed_url : String) : Int64?
      @db.query_one?(
        "SELECT id FROM feeds WHERE url = ?",
        feed_url,
        as: Int64
      )
    end

    def recent_clustering_items(hours_back : Int32 = 24, max_items : Int32 = 1000) : Array(ClusteringItemRow)
      cutoff = (Time.utc - hours_back.hours).to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)

      items = [] of ClusteringItemRow

      query = <<-SQL
        SELECT i.id, i.title, i.link, i.pub_date, f.url as feed_url, f.title as feed_title, f.favicon, f.header_color
        FROM items i
        JOIN feeds f ON i.feed_id = f.id
        WHERE i.cluster_id IS NOT NULL
        AND i.pub_date >= ?
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

          pub_date = pub_date_str.try do |date_str|
            begin
              Time.parse(date_str, QuickHeadlines::Constants::DB_TIME_FORMAT, Time::Location::UTC)
            rescue Time::Format::Error
              nil
            end
          end

          items << ClusteringItemRow.new(
            id: id,
            title: title,
            link: link,
            pub_date: pub_date,
            feed_url: feed_url,
            feed_title: feed_title,
            favicon: favicon,
            header_color: header_color,
          )
        end
      end

      items
    end

    def all_clusters : Array({id: Int64, representative_id: Int64, item_count: Int32})
      clusters = [] of {id: Int64, representative_id: Int64, item_count: Int32}

      query = <<-SQL
        SELECT cluster_id, MIN(id) as representative_id, COUNT(*) as item_count
        FROM items
        WHERE cluster_id IS NOT NULL
        GROUP BY cluster_id
        ORDER BY MIN(pub_date) DESC
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

    def get_cluster_items_full(cluster_id : Int64) : Array(ClusteringItemRow)
      items = [] of ClusteringItemRow

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

          pub_date = pub_date_str.try do |date_str|
            begin
              Time.parse(date_str, QuickHeadlines::Constants::DB_TIME_FORMAT, Time::Location::UTC)
            rescue Time::Format::Error
              nil
            end
          end

          items << ClusteringItemRow.new(
            id: id,
            title: title,
            link: link,
            pub_date: pub_date,
            feed_url: feed_url,
            feed_title: feed_title,
            favicon: favicon,
            header_color: header_color,
          )
        end
      end

      items
    end
  end
end

require "db"
require "mutex"
require "time"
require "../services/clustering_service"
require "../repositories/repository_base"

module QuickHeadlines::Storage
  class ClusteringStore
    record ItemKey, feed_url : String, link : String

    MAX_LSH_CANDIDATES = 500

    def initialize(@db : DB::Database, @mutex : Mutex)
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
        @db.transaction do
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
        @db.transaction do
          clusters.each do |rep_id, members|
            next if members.empty?
            placeholders = QuickHeadlines::Repositories::RepositoryBase.placeholders(members.size)
            sql = "UPDATE items SET cluster_id = ? WHERE id IN (#{placeholders})"
            args = [rep_id] + members
            @db.exec(sql, args: args)
          end
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

    def get_item_ids_batch(items : Array(ItemKey)) : Hash(String, Int64)
      result = {} of String => Int64
      return result if items.empty?

      feed_urls = items.map(&.feed_url).uniq!
      feed_url_to_id = {} of String => Int64

      if !feed_urls.empty?
        placeholders = QuickHeadlines::Repositories::RepositoryBase.placeholders(feed_urls.size)
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
        placeholders = QuickHeadlines::Repositories::RepositoryBase.placeholders(links.size)
        query = "SELECT link, id FROM items WHERE feed_id = ? AND link IN (#{placeholders})"
        args = [] of DB::Any
        args << feed_id
        links.each { |link| args << link }
        @db.query(query, args: args) do |rows|
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

    def get_cluster_items_full(cluster_id : Int64) : Array(ClusteringItemRow)
      items = [] of ClusteringItemRow

      query = <<-SQL
        SELECT i.id, i.title, i.link, i.pub_date, f.url as feed_url, f.title as feed_title, f.favicon, f.favicon_data, f.header_color
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
          favicon_data = rows.read(String?)
          header_color = rows.read(String?)

          pub_date = QuickHeadlines::Repositories::RepositoryBase.parse_db_time(pub_date_str)

          items << ClusteringItemRow.new(
            id: id,
            title: title,
            link: link,
            pub_date: pub_date,
            feed_url: feed_url,
            feed_title: feed_title,
            favicon: favicon,
            favicon_data: favicon_data,
            header_color: header_color,
          )
        end
      end

      items
    end
  end
end

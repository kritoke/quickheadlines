require "athena"
require "json"
require "lexis-minhash"
require "../repositories/cluster_repository"
require "./clustering_engine"

class Quickheadlines::Services::ClusteringService
  @db : DB::Database
  @cluster_repository : Quickheadlines::Repositories::ClusterRepository?

  def initialize(@db : DB::Database, @cluster_repository : Quickheadlines::Repositories::ClusterRepository? = nil)
  end

  private def cluster_repository : Quickheadlines::Repositories::ClusterRepository
    @cluster_repository ||= Quickheadlines::Repositories::ClusterRepository.new(@db)
  end

  def compute_cluster_for_item(item_id : Int64, title : String, cache : FeedCache, item_feed_id : Int64? = nil, threshold : Float64 = 0.35) : Int64?
    return unless ClusteringEngine.can_cluster?(title)

    title_set = ClusteringEngine.word_set(title)
    signature = ClusteringEngine.compute_minhash_signature(title)

    cache.store_item_signature(item_id, signature)

    bands = LexisMinhash::Engine.generate_bands(signature)
    band_hashes = bands.map { |band| band[1] }
    cache.store_lsh_bands(item_id, band_hashes)

    candidates = cache.find_lsh_candidates(signature)

    if candidates.empty?
      cache.assign_cluster(item_id, item_id)
      return item_id
    end

    best_match = nil
    best_similarity = 0.0_f64
    best_title = ""
    best_feed_id = nil

    candidates.each do |candidate_id|
      next if candidate_id == item_id

      candidate_signature = cache.get_item_signature(candidate_id)
      next unless candidate_signature

      candidate_feed_id = cache.get_item_feed_id(candidate_id)
      if item_feed_id && candidate_feed_id == item_feed_id
        next
      end

      candidate_title = cache.get_item_title(candidate_id)
      next unless candidate_title

      candidate_set = ClusteringEngine.word_set(candidate_title)
      similarity = ClusteringEngine.overlap_coefficient(title_set, candidate_set)

      if similarity > best_similarity
        best_similarity = similarity
        best_match = candidate_id
        best_title = candidate_title
        best_feed_id = candidate_feed_id
      end
    end

    STDERR.puts "[Clustering] Best match similarity: #{best_similarity.round(2)} (threshold: #{threshold})" if ENV["DEBUG_CLUSTERING"]?

    if best_match && best_similarity >= threshold
      cluster_items = cache.get_cluster_items(best_match)
      if cluster_items.any? { |id| id != best_match }
        cluster_id = cluster_items.first
      else
        cluster_id = best_match
      end
      cache.assign_cluster(item_id, cluster_id)
      STDERR.puts "[Clustering] Clustered '#{title[0...50]}...' with '#{best_title[0...50]}...'" if ENV["DEBUG_CLUSTERING"]?
      cluster_id
    else
      cache.assign_cluster(item_id, item_id)
      STDERR.puts "[Clustering] Created new cluster for '#{title[0...50]}...'" if ENV["DEBUG_CLUSTERING"]?
      item_id
    end
  end

  def get_all_clusters_from_db : Array(Quickheadlines::Entities::Cluster)
    cluster_repository.find_all
  end

  def cluster_uncategorized(limit : Int32 = 5000, threshold : Float64 = 0.35) : Int32
    cache = FeedCache.instance
    db = @db

    processed = 0
    STATE.clustering = true
    begin
      STDERR.puts "[#{Time.local}] Starting clustering (streaming rows, threshold: #{threshold})"

      db.query("SELECT id, title, link, feed_id FROM items WHERE (cluster_id IS NULL OR cluster_id = id) AND (pub_date IS NULL OR pub_date <= datetime('now', '+1 day')) ORDER BY pub_date DESC LIMIT ?", limit) do |rows|
        rows.each do
          id = rows.read(Int64)
          title = rows.read(String)
          link = rows.read(String)
          feed_id = rows.read(Int64)

          next if title.empty?

          compute_cluster_for_item(id, title, FeedCache.instance, feed_id, threshold)
          processed += 1
          if processed % 50 == 0
            STDERR.puts "[#{Time.local}] Processed #{processed} items..."
          end
        end
      end

      STDERR.puts "[#{Time.local}] Clustering complete: #{processed} items processed"
    ensure
      STATE.clustering = false
    end

    processed
  end

  def recluster_all(limit : Int32 = 5000, threshold : Float64 = 0.35) : Int32
    cluster_repository.clear_all_metadata

    items = [] of {id: Int64, title: String, link: String, pub_date: Time?, feed_id: Int64}
    @db.query("SELECT id, title, link, pub_date, feed_id FROM items WHERE pub_date IS NULL OR pub_date <= datetime('now', '+1 day') ORDER BY pub_date DESC LIMIT ?", limit) do |rows|
      rows.each do
        id = rows.read(Int64)
        title = rows.read(String)
        link = rows.read(String)
        pub_date_str = rows.read(String?)
        feed_id = rows.read(Int64)
        pub_date = pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }
        items << {id: id, title: title, link: link, pub_date: pub_date, feed_id: feed_id}
      end
    end

    STDERR.puts "[#{Time.local}] Found #{items.size} items to re-cluster (threshold: #{threshold})"

    processed = 0
    STATE.clustering = true
    begin
      items.each do |item|
        next if item[:title].empty?
        compute_cluster_for_item(item[:id], item[:title], FeedCache.instance, item[:feed_id], threshold)
        processed += 1
        if processed % 50 == 0
          STDERR.puts "[#{Time.local}] Processed #{processed} items..."
        end
      end
      STDERR.puts "[#{Time.local}] Re-clustering complete: #{processed} items processed"
    ensure
      STATE.clustering = false
    end

    processed
  end

  def recluster_with_lsh(limit : Int32 = 5000, threshold : Float64 = 0.35, bands : Int32 = 20) : Int32
    cache = FeedCache.instance

    items = [] of ClusteringItem
    @db.query("SELECT i.id, i.title, i.feed_id, f.url FROM items i JOIN feeds f ON i.feed_id = f.id WHERE i.pub_date IS NULL OR i.pub_date <= datetime('now', '+1 day') ORDER BY i.pub_date DESC LIMIT ?", limit) do |rows|
      rows.each do
        id = rows.read(Int64)
        title = rows.read(String)
        feed_id = rows.read(Int64)
        feed_url = rows.read(String)
        items << ClusteringItem.new(id: id, title: title, feed_id: feed_id, feed_url: feed_url)
      end
    end

    STDERR.puts "[#{Time.local}] Found #{items.size} items to re-cluster with LSH (threshold: #{threshold}, bands: #{bands})"

    STATE.clustering = true
    processed = 0
    begin
      rep_map = ClusteringEngine.cluster_items(items, threshold, bands)
      cache.assign_clusters_bulk(rep_map)
      processed = items.count { |i| ClusteringEngine.can_cluster?(i.title) }
      STDERR.puts "[#{Time.local}] Re-clustering with LSH complete: #{processed} items clustered into #{rep_map.size} groups"
    ensure
      STATE.clustering = false
    end

    processed
  end
end

def clustering_service : Quickheadlines::Services::ClusteringService
  db_service = DatabaseService.instance
  Quickheadlines::Services::ClusteringService.new(db_service.db)
end

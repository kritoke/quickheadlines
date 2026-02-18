require "athena"
require "json"
require "lexis-minhash"

module ClusteringUtilities
  STOP_WORDS = Set.new([
    "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
    "of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
    "be", "have", "has", "had", "do", "does", "did", "will", "would",
    "could", "should", "may", "might", "must", "shall", "can", "need",
    "this", "that", "these", "those", "it",
    "time", "times", "day", "days", "week", "weeks", "month", "months",
    "year", "years",
    "says", "said", "just", "now", "how", "what", "when", "where", "why",
    "building", "built", "build", "building", "using", "via", "get", "got",
    "new", "make", "making", "way", "use", "youre", "your",
    "works", "work", "working", "today", "where",
  ])

  MIN_WORDS_FOR_CLUSTERING = 4

  def self.normalize_headline(text : String) : String
    return "" if text.empty?
    normalized = text.downcase.strip
    words = normalized.split(/\s+/)
    filtered = words.reject { |word| STOP_WORDS.includes?(word) }
    filtered.join(" ")
  end

  def self.word_count(text : String) : Int32
    normalized = normalize_headline(text)
    return 0 if normalized.empty?
    normalized.split(/\s+/).size
  end

  def self.word_set(text : String) : Set(String)
    normalized = normalize_headline(text)
    return Set(String).new if normalized.empty?
    normalized.split(/\s+/).to_set
  end

  def self.jaccard_similarity(set1 : Set(String), set2 : Set(String)) : Float64
    return 0.0 if set1.empty? && set2.empty?
    return 0.0 if set1.empty? || set2.empty?
    intersection = set1 & set2
    union = set1 | set2
    return 0.0 if union.size == 0
    intersection.size.to_f64 / union.size.to_f64
  end

  # Overlap coefficient - measures how much one set overlaps with another
  # Better for comparing sets of different sizes (more forgiving for short text)
  def self.overlap_coefficient(set1 : Set(String), set2 : Set(String)) : Float64
    return 0.0 if set1.empty? || set2.empty?
    intersection = set1 & set2
    return 0.0 if intersection.empty?
    min_size = {set1.size, set2.size}.min
    intersection.size.to_f64 / min_size.to_f64
  end
end

class Quickheadlines::Services::ClusteringService
  include ClusteringUtilities

  @db : DB::Database

  def initialize(@db : DB::Database)
  end

  def compute_cluster_for_item(item_id : Int64, title : String, cache : FeedCache, item_feed_id : Int64? = nil, threshold : Float64 = 0.35) : Int64?
    return nil if title.empty?
    return nil if ClusteringUtilities.word_count(title) < ClusteringUtilities::MIN_WORDS_FOR_CLUSTERING

    # Compute normalized word set for Jaccard similarity
    title_set = ClusteringUtilities.word_set(title)

    # Compute MinHash signature (still used for LSH candidate generation)
    document = LexisMinhash::SimpleDocument.new(title)
    signature = LexisMinhash::Engine.compute_signature(document)

    # Store the signature
    cache.store_item_signature(item_id, signature)

    # Generate LSH bands and extract band hashes (tuples contain {band_index, band_hash})
    bands = LexisMinhash::Engine.generate_bands(signature)
    band_hashes = bands.map { |band| band[1] }
    cache.store_lsh_bands(item_id, band_hashes)

    # Find candidates via LSH
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

      candidate_set = ClusteringUtilities.word_set(candidate_title)

      similarity = ClusteringUtilities.overlap_coefficient(title_set, candidate_set)

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
    clusters = [] of Quickheadlines::Entities::Cluster

    query = <<-SQL
      SELECT
        c.id as cluster_id,
        c.representative_id,
        i.id as item_id,
        i.title as item_title,
        i.link as item_link,
        i.pub_date as item_pub_date,
        f.url as feed_url,
        f.title as feed_title,
        f.favicon,
        f.header_color
      FROM (
        SELECT cluster_id as id, MIN(id) as representative_id
        FROM items
        WHERE cluster_id IS NOT NULL
        GROUP BY cluster_id
      ) c
      JOIN items i ON i.cluster_id = c.id
      JOIN feeds f ON i.feed_id = f.id
      ORDER BY c.id, i.id ASC
      SQL

    cluster_items = Hash(Int64, Array({id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?})).new

    @db.query(query) do |rows|
      rows.each do
        cluster_id = rows.read(Int64)
        representative_id = rows.read(Int64)
        item_id = rows.read(Int64)
        item_title = rows.read(String)
        item_link = rows.read(String)
        item_pub_date_str = rows.read(String?)
        feed_url = rows.read(String)
        feed_title = rows.read(String)
        favicon = rows.read(String?)
        header_color = rows.read(String?)

        item_pub_date = item_pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

        cluster_items[cluster_id] ||= [] of {id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?}
        cluster_items[cluster_id] << {
          id:           item_id,
          title:        item_title,
          link:         item_link,
          pub_date:     item_pub_date,
          feed_url:     feed_url,
          feed_title:   feed_title,
          favicon:      favicon,
          header_color: header_color,
        }
      end
    end

    cluster_items.each do |_cluster_id, items|
      next if items.empty?

      rep_data = items.first

      representative = Quickheadlines::Entities::Story.new(
        id: rep_data[:id].to_s,
        title: rep_data[:title],
        link: rep_data[:link],
        pub_date: rep_data[:pub_date],
        feed_title: rep_data[:feed_title],
        feed_url: rep_data[:feed_url],
        feed_link: "",
        favicon: rep_data[:favicon],
        favicon_data: rep_data[:favicon],
        header_color: rep_data[:header_color]
      )

      others = items[1..].map do |item|
        Quickheadlines::Entities::Story.new(
          id: item[:id].to_s,
          title: item[:title],
          link: item[:link],
          pub_date: item[:pub_date],
          feed_title: item[:feed_title],
          feed_url: item[:feed_url],
          feed_link: "",
          favicon: item[:favicon],
          favicon_data: item[:favicon],
          header_color: item[:header_color]
        )
      end

      clusters << Quickheadlines::Entities::Cluster.new(
        id: items.first[:id].to_s,
        representative: representative,
        others: others,
        size: items.size
      )
    end

    clusters
  end

  # Cluster uncategorized items (items with cluster_id NULL or cluster_id = id)
  # Returns number of items processed
  def cluster_uncategorized(limit : Int32 = 5000, threshold : Float64 = 0.35) : Int32
    cache = FeedCache.instance
    db = @db

    processed = 0
    STATE.is_clustering = true
    begin
      STDERR.puts "[#{Time.local}] Starting clustering (streaming rows, threshold: #{threshold})"

      db.query("SELECT id, title, link, pub_date, feed_id FROM items WHERE cluster_id IS NULL OR cluster_id = id ORDER BY pub_date DESC LIMIT ?", limit) do |rows|
        rows.each do
          id = rows.read(Int64)
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          feed_id = rows.read(Int64)
          # parse pub_date only if needed by downstream code
          # pub_date = pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

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
      STATE.is_clustering = false
    end

    processed
  end

  # Clear clustering metadata and recluster all items (up to limit)
  def recluster_all(limit : Int32 = 5000, threshold : Float64 = 0.35) : Int32
    cache = FeedCache.instance
    cache.clear_clustering_metadata

    items = [] of {id: Int64, title: String, link: String, pub_date: Time?, feed_id: Int64}
    @db.query("SELECT id, title, link, pub_date, feed_id FROM items ORDER BY pub_date DESC LIMIT ?", limit) do |rows|
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
    STATE.is_clustering = true
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
      STATE.is_clustering = false
    end

    processed
  end
end

def clustering_service : Quickheadlines::Services::ClusteringService
  db_service = DatabaseService.instance
  Quickheadlines::Services::ClusteringService.new(db_service.db)
end

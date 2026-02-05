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

  # Replaced by LexisMinhash constants
  # Keeping for reference during migration
  #
  # SHORT_HEADLINE_THRESHOLD = 0.85
  MIN_WORDS_FOR_CLUSTERING = 5

  # JACCARD_FALLBACK_THRESHOLD = 0.45
  # WORD_COVERAGE_THRESHOLD = 0.70
  # MIN_SHARED_KEYWORDS = 2
  # MIN_WORD_LENGTH = 5

  def self.normalize_headline(text : String) : String
    return "" if text.empty?
    normalized = text.downcase.strip
    words = normalized.split(/\s+/)
    filtered = words.reject { |word| STOP_WORDS.includes?(word) }
    filtered.join(" ")
  end

  # Replaced by LexisMinhash::Engine.similarity for MinHash-based similarity estimation
  # Keeping for reference during migration
  #
  # def self.jaccard_similarity(text1 : String, text2 : String) : Float64
  #   norm1 = normalize_headline(text1)
  #   norm2 = normalize_headline(text2)
  #
  #   words1 = Set.new(norm1.split(/\s+/))
  #   words2 = Set.new(norm2.split(/\s+/))
  #
  #   intersection = words1 & words2
  #   union = words1 | words2
  #
  #   return 0.0_f64 if union.empty?
  #   intersection.size.to_f64 / union.size.to_f64
  # end
  #
  # def self.word_coverage_similarity(text1 : String, text2 : String) : Float64
  #   norm1 = normalize_headline(text1)
  #   norm2 = normalize_headline(text2)
  #
  #   words1 = norm1.split(/\s+/).select { |w| w.size >= MIN_WORD_LENGTH }
  #   words2 = norm2.split(/\s+/).select { |w| w.size >= MIN_WORD_LENGTH }
  #
  #   return 0.0_f64 if words1.empty? || words2.empty?
  #
  #   matched = Set(String).new
  #
  #   words1.each do |w1|
  #     if words2.includes?(w1)
  #       matched << w1
  #     else
  #       words2.each do |w2|
  #         if w1.includes?(w2) || w2.includes?(w1)
  #           matched << w1
  #           break
  #         elsif levenshtein_distance(w1, w2) <= 2
  #           matched << w1
  #           break
  #         end
  #       end
  #     end
  #   end
  #
  #   return 0.0_f64 if matched.size < MIN_SHARED_KEYWORDS
  #
  #   shared = matched.size.to_f64
  #   coverage1 = shared / words1.size
  #   coverage2 = shared / words2.size
  #
  #   {coverage1, coverage2}.min
  # end
  #
  # def self.hybrid_similarity(text1 : String, text2 : String) : Float64
  #   jac = jaccard_similarity(text1, text2)
  #   word_cov = word_coverage_similarity(text1, text2)
  #
  #   if jac < JACCARD_FALLBACK_THRESHOLD && word_cov > jac
  #     STDERR.puts "[Clustering] Jaccard=#{jac.round(2)} < #{JACCARD_FALLBACK_THRESHOLD}, using word_coverage=#{word_cov.round(2)}" if ENV["DEBUG_CLUSTERING"]?
  #     return word_cov
  #   end
  #
  #   jac
  # end

  def self.word_count(text : String) : Int32
    normalized = normalize_headline(text)
    return 0 if normalized.empty?
    normalized.split(/\s+/).size
  end

  # Replaced by LexisMinhash::SimpleDocument which handles stop-word filtering internally
  # Keeping for reference during migration
  #
  # def self.extract_keywords(text : String) : Array(String)
  #   normalized = normalize_headline(text)
  #   words = normalized.split(/\s+/)
  #   words.select { |w| w.size > 4 }.first(5)
  # end

  # Only used by word_coverage_similarity which is replaced by LexisMinhash::Engine.similarity
  # Keeping for reference during migration
  #
  # private def self.levenshtein_distance(s1 : String, s2 : String) : Int32
  #   return (s1.size - s2.size).abs if s1.size == 0 || s2.size == 0
  #
  #   matrix = Array(Array(Int32)).new(s1.size + 1) { |i| Array(Int32).new(s2.size + 1, 0) }
  #
  #   (0..s1.size).each { |i| matrix[i][0] = i }
  #   (0..s2.size).each { |j| matrix[0][j] = j }
  #
  #   (1..s1.size).each do |i|
  #     (1..s2.size).each do |j|
  #       cost = s1[i - 1] == s2[j - 1] ? 0 : 1
  #       matrix[i][j] = {
  #         matrix[i - 1][j] + 1,
  #         matrix[i][j - 1] + 1,
  #         matrix[i - 1][j - 1] + cost,
  #       }.min
  #     end
  #   end
  #
  #   matrix[s1.size][s2.size]
  # end

end

class Quickheadlines::Services::ClusteringService
  include ClusteringUtilities

  @db : DB::Database

  def initialize(@db : DB::Database)
  end

  def compute_cluster_for_item(item_id : Int64, title : String, cache : FeedCache, item_feed_id : Int64? = nil) : Int64?
    return nil if title.empty?
    return nil if ClusteringUtilities.word_count(title) < ClusteringUtilities::MIN_WORDS_FOR_CLUSTERING

    # Compute MinHash signature
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

      # Skip if candidate is from the same feed (likely a duplicate)
      candidate_feed_id = cache.get_item_feed_id(candidate_id)
      if item_feed_id && candidate_feed_id == item_feed_id
        next
      end

      similarity = LexisMinhash::Engine.similarity(signature, candidate_signature)
      if similarity > best_similarity
        best_similarity = similarity
        best_match = candidate_id
        best_title = cache.get_item_title(candidate_id) || ""
        best_feed_id = candidate_feed_id
      end
    end

    threshold = 0.75_f64

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

  def cluster_stories(stories : Array(Quickheadlines::Entities::Story)) : Array(Quickheadlines::Entities::Cluster)
    [] of Quickheadlines::Entities::Cluster
  end

  def get_cluster(story_id : String) : Quickheadlines::Entities::Cluster?
    nil
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
end

def clustering_service : Quickheadlines::Services::ClusteringService
  db_service = DatabaseService.instance
  Quickheadlines::Services::ClusteringService.new(db_service.db)
end

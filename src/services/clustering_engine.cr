require "lexis-minhash"

module QuickHeadlines::Services
  record ClusteringItem,
    id : Int64,
    title : String,
    feed_id : Int64,
    feed_url : String

  module ClusteringEngine
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

    def self.extract_base_domain(url : String) : String
      return "" if url.empty?
      begin
        uri = URI.parse(url)
        host = uri.host || ""
        return "" if host.empty?
        host.downcase
      rescue URI::Error
        ""
      end
    end

    def self.same_base_domain?(url1 : String, url2 : String) : Bool
      return false if url1.empty? || url2.empty?
      domain1 = extract_base_domain(url1)
      domain2 = extract_base_domain(url2)
      return false if domain1.empty? || domain2.empty?
      domain1 == domain2
    end

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

    def self.overlap_coefficient(set1 : Set(String), set2 : Set(String)) : Float64
      return 0.0 if set1.empty? || set2.empty?
      intersection = set1 & set2
      return 0.0 if intersection.empty?
      min_size = {set1.size, set2.size}.min
      intersection.size.to_f64 / min_size.to_f64
    end

    def self.compute_minhash_signature(title : String) : Array(UInt32)
      document = LexisMinhash::SimpleDocument.new(title)
      LexisMinhash::Engine.compute_signature(document)
    end

    def self.can_cluster?(title : String) : Bool
      !title.empty? && word_count(title) >= MIN_WORDS_FOR_CLUSTERING
    end

    def self.find_similar_pairs_lsh(
      items : Array(ClusteringItem),
      threshold : Float64 = 0.35,
      bands : Int32 = 20,
    ) : Array(Tuple(Int64, Int64, Float64))
      return [] of Tuple(Int64, Int64, Float64) if items.empty?

      index = LexisMinhash::LSHIndex.new(bands: bands, expected_docs: items.size)
      signatures = {} of Int64 => Array(UInt32)
      items_map = {} of Int64 => ClusteringItem

      items.each do |item|
        next unless can_cluster?(item.title)

        sig = compute_minhash_signature(item.title)
        signatures[item.id] = sig
        items_map[item.id] = item
        index.add_with_signature(item.id.to_i32, sig)
      end

      candidate_pairs = index.find_similar_pairs(threshold)
      verified_pairs = [] of Tuple(Int64, Int64, Float64)

      candidate_pairs.each do |pair|
        a = pair[0].to_i64
        b = pair[1].to_i64

        next unless items_map.has_key?(a) && items_map.has_key?(b)
        next if items_map[a].feed_id == items_map[b].feed_id
        next if same_base_domain?(items_map[a].feed_url, items_map[b].feed_url)

        set_a = word_set(items_map[a].title)
        set_b = word_set(items_map[b].title)
        sim = overlap_coefficient(set_a, set_b)

        if sim >= threshold
          verified_pairs << {a, b, sim}
        end
      end

      verified_pairs
    end

    def self.build_clusters_from_pairs(
      pairs : Array(Tuple(Int64, Int64, Float64)),
      item_ids : Array(Int64),
    ) : Hash(Int64, Array(Int64))
      parent = {} of Int64 => Int64

      find = ->(x : Int64) do
        parent[x] ||= x
        while parent[x] != x
          parent[x] = parent[parent[x]]
          x = parent[x]
        end
        x
      end

      union = ->(a : Int64, b : Int64) do
        ra = find.call(a)
        rb = find.call(b)
        return if ra == rb
        if ra < rb
          parent[rb] = ra
        else
          parent[ra] = rb
        end
      end

      pairs.each do |pair|
        union.call(pair[0], pair[1])
      end

      clusters = {} of Int64 => Array(Int64)
      item_ids.each do |id|
        root = find.call(id)
        clusters[root] ||= [] of Int64
        clusters[root] << id
      end

      rep_map = {} of Int64 => Array(Int64)
      clusters.each do |_root, members|
        rep = members.min
        rep_map[rep] = members
      end

      rep_map
    end

    def self.cluster_items(
      items : Array(ClusteringItem),
      threshold : Float64 = 0.35,
      bands : Int32 = 20,
    ) : Hash(Int64, Array(Int64))
      return {} of Int64 => Array(Int64) if items.empty?

      pairs = find_similar_pairs_lsh(items, threshold, bands)
      item_ids = items.select { |i| can_cluster?(i.title) }.map(&.id)
      build_clusters_from_pairs(pairs, item_ids)
    end
  end
end

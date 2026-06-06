require "athena"
require "json"
require "lexis-minhash"
require "../repositories/cluster_repository"
require "../dtos/cluster_dto"
require "../dtos/api_responses"
require "./clustering_engine"
require "../infrastructure/actor"

# ClusteringActor — serializes heavy LSH clustering operations.
#
# All clustering mutations go through the actor mailbox. Read-only queries
# can still go direct to the database.
#
class QuickHeadlines::Services::ClusteringActor < Actor
  # =========================================================================
  # Messages
  # =========================================================================

  # Call messages (request-reply) — blocks until clustering completes
  def_call recluster(cache : FeedCache, limit : Int32, threshold : Float64, bands : Int32), Int32
  def_call is_clustering, Bool

  # =========================================================================
  # Actor state
  # =========================================================================

  @clustering : Bool = false
  @db_service : DatabaseService
  @db : DB::Database
  @cluster_repository : QuickHeadlines::Repositories::ClusterRepository?

  def initialize(@db_service : DatabaseService, @name : String = "ClusteringActor")
    super(@name, mailbox_size: 10)
    @db = @db_service.db
  end

  # Singleton access — lazily initialized with explicit db_service
  @@instance : ClusteringActor?
  @@instance_mutex = Mutex.new

  def self.instance : ClusteringActor
    @@instance_mutex.synchronize do
      @@instance ||= ClusteringActor.new(DatabaseService.instance).tap(&.start)
    end
  end

  # Create or get instance with explicit db_service (for tests)
  def self.instance(db_service : DatabaseService) : ClusteringActor
    @@instance_mutex.synchronize do
      @@instance ||= ClusteringActor.new(db_service).tap(&.start)
    end
  end

  def self.reset : Nil
    if inst = @@instance
      inst.shutdown rescue nil
    end
    @@instance = nil
  end

  # =========================================================================
  # Dispatch
  # =========================================================================

  def dispatch(message : Message) : Nil
    case message
    when CallRecluster    then message.deliver_reply_json(handle_recluster(message.cache, message.limit, message.threshold, message.bands).to_json)
    when CallIsClustering then message.deliver_reply_json(@clustering.to_json)
    else                       raise "Unknown message: #{message.class.name}"
    end
  end

  # =========================================================================
  # Handlers
  # =========================================================================

  private def handle_recluster(cache : FeedCache, limit : Int32, threshold : Float64, bands : Int32) : Int32
    if @clustering
      Log.for("quickheadlines.clustering").info { "Clustering already in progress, skipping" }
      return 0
    end

    @clustering = true

    begin
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

      Log.for("quickheadlines.clustering").info { "Found #{items.size} items to re-cluster with LSH (threshold: #{threshold}, bands: #{bands})" }

      rep_map = ClusteringEngine.cluster_items(items, threshold, bands)
      cache.assign_clusters_bulk(rep_map)
      processed = items.count { |i| ClusteringEngine.can_cluster?(i.title) }
      Log.for("quickheadlines.clustering").info { "Re-clustering with LSH complete: #{processed} items clustered into #{rep_map.size} groups" }
      processed
    rescue ex
      Log.for("quickheadlines.clustering").error(exception: ex) { "Clustering failed" }
      0
    ensure
      @clustering = false
    end
  end
end

# Backward-compatible ClusteringService — delegates to ClusteringActor for mutations
class QuickHeadlines::Services::ClusteringService
  @db_service : DatabaseService
  @db : DB::Database
  @cluster_repository : QuickHeadlines::Repositories::ClusterRepository?
  @actor : ClusteringActor

  def initialize(@db_service : DatabaseService, @cluster_repository : QuickHeadlines::Repositories::ClusterRepository? = nil)
    @db = @db_service.db
    @actor = ClusteringActor.instance(@db_service)
  end

  private def cluster_repository : QuickHeadlines::Repositories::ClusterRepository
    @cluster_repository ||= QuickHeadlines::Repositories::ClusterRepository.new(@db_service)
  end

  private def best_cluster_match(candidates : Array(Int64), item_id : Int64, title_set : Set(String), cache : FeedCache, item_feed_id : Int64?) : ClusterMatchResult
    best_match = nil
    best_similarity = 0.0_f64
    best_title = ""
    best_feed_id = nil

    candidates.each do |candidate_id|
      next if candidate_id == item_id

      candidate_signature = cache.get_item_signature(candidate_id)
      next unless candidate_signature

      candidate_feed_id = cache.get_item_feed_id(candidate_id)
      next if item_feed_id && candidate_feed_id == item_feed_id

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

    ClusterMatchResult.new(best_match, best_similarity, best_title, best_feed_id)
  end

  private struct ClusterMatchResult
    getter match_id : Int64?
    getter similarity : Float64
    getter match_title : String
    getter match_feed_id : Int64?

    def initialize(@match_id : Int64?, @similarity : Float64, @match_title : String, @match_feed_id : Int64?)
    end
  end

  private def assign_cluster_item(item_id : Int64, match : ClusterMatchResult, threshold : Float64, title : String, cache : FeedCache) : Int64
    if match.match_id && match.similarity >= threshold
      cluster_items = cache.get_cluster_items(match.match_id)
      cluster_id = cluster_items.any? { |id| id != match.match_id } ? cluster_items.first : match.match_id
      cache.assign_cluster(item_id, cluster_id)
      Log.for("quickheadlines.clustering").debug { "Clustered '#{title[0...QuickHeadlines::Constants::CLUSTER_TITLE_TRUNCATE_LENGTH]}...' with '#{match.match_title[0...QuickHeadlines::Constants::CLUSTER_TITLE_TRUNCATE_LENGTH]}...'" } if ENV["DEBUG_CLUSTERING"]?
      cluster_id
    else
      cache.assign_cluster(item_id, item_id)
      Log.for("quickheadlines.clustering").debug { "Created new cluster for '#{title[0...QuickHeadlines::Constants::CLUSTER_TITLE_TRUNCATE_LENGTH]}...'" } if ENV["DEBUG_CLUSTERING"]?
      item_id
    end
  end

  def compute_item_cluster(item_id : Int64, title : String, cache : FeedCache, item_feed_id : Int64? = nil, threshold : Float64 = 0.35) : Int64?
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

    best_match = best_cluster_match(candidates, item_id, title_set, cache, item_feed_id)

    Log.for("quickheadlines.clustering").debug { "Best match similarity: #{best_match.similarity.round(2)} (threshold: #{threshold})" } if ENV["DEBUG_CLUSTERING"]?

    assign_cluster_item(item_id, best_match, threshold, title, cache)
  end

  def all_clusters_from_db : Array(QuickHeadlines::Entities::Cluster)
    fetch_limit = StateStore.config.try(&.clustering).try(&.max_fetch_items) || 1000
    cluster_repository.find_all(fetch_limit)
  end

  def cluster_responses : QuickHeadlines::DTOs::ClustersResponse
    clusters = all_clusters_from_db
    cluster_responses = clusters.map { |cluster| QuickHeadlines::DTOs::ClusterResponse.from_entity(cluster) }
    QuickHeadlines::DTOs::ClustersResponse.new(
      clusters: cluster_responses,
      total_count: cluster_responses.size,
    )
  end

  def get_cluster_items_response(cluster_id : String, feed_cache : FeedCache) : QuickHeadlines::DTOs::ClusterItemsResponse
    parsed_id = cluster_id.to_i64?

    if parsed_id.nil?
      return QuickHeadlines::DTOs::ClusterItemsResponse.new(
        cluster_id: cluster_id,
        items: [] of QuickHeadlines::DTOs::StoryResponse,
      )
    end

    db_items = begin
      feed_cache.get_cluster_items_full(parsed_id)
    rescue ex
      Log.for("quickheadlines.clustering").error(exception: ex) { "Failed to fetch cluster items for cluster #{cluster_id}" }
      return QuickHeadlines::DTOs::ClusterItemsResponse.new(
        cluster_id: cluster_id,
        items: [] of QuickHeadlines::DTOs::StoryResponse,
      )
    end

    items = db_items.map do |item|
      QuickHeadlines::DTOs::StoryResponse.from_cluster_item(item)
    end

    QuickHeadlines::DTOs::ClusterItemsResponse.new(
      cluster_id: cluster_id,
      items: items,
    )
  end

  # Delegate recluster_with_lsh to ClusteringActor (synchronous — blocks until complete)
  def recluster_with_lsh(cache : FeedCache, limit : Int32 = 2000, threshold : Float64 = 0.35, bands : Int32 = 20) : Int32
    @actor.recluster(cache, limit, threshold, bands)
  end

  def recluster_with_lsh(limit : Int32 = 2000, threshold : Float64 = 0.35, bands : Int32 = 20) : Int32
    recluster_with_lsh(FeedCache.instance, limit, threshold, bands)
  end
end

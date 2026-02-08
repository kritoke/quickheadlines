require "gc"
require "./services/clustering_service"
require "./storage"

# Run clustering asynchronously with concurrency limiting
CLUSTERING_JOBS = Atomic(Int32).new(0)

def async_clustering(feeds : Array(FeedData))
  clustering_channel = Channel(Nil).new(10)
  STATE.is_clustering = true
  CLUSTERING_JOBS.set(feeds.size)

  spawn do
    feeds.each do |feed_data|
      spawn do
        clustering_channel.send(nil)
        begin
          process_feed_item_clustering(feed_data)
        ensure
          clustering_channel.receive
          if CLUSTERING_JOBS.sub(1) <= 1
            STATE.is_clustering = false
          end
        end
      end
    end
  end
end

def compute_cluster_for_item(item_id : Int64, title : String, item_feed_id : Int64? = nil) : Int64?
  cache = FeedCache.instance
  service = clustering_service
  service.compute_cluster_for_item(item_id, title, cache, item_feed_id)
end

def process_feed_item_clustering(feed_data : FeedData) : Nil
  return if feed_data.items.empty?
  cache = FeedCache.instance
  feed_id = cache.get_feed_id(feed_data.url)
  feed_data.items.each do |item|
    item_id = cache.get_item_id(feed_data.url, item.link)
    next unless item_id
    compute_cluster_for_item(item_id, item.title, feed_id)
  end
end

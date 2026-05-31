require "spec"
require "../src/config"
require "../src/models"
require "../src/utils"
require "../src/entities/story"
require "../src/entities/cluster"
require "../src/fetcher"
require "../src/storage"
require "../src/favicon_storage"
require "../src/services/clustering_service"
require "../src/services/database_service"
require "../src/websocket"

# Reset actor singletons before each test to prevent state pollution
Spec.before_each do
  QuickHeadlines::Services::ClusteringActor.reset
end

def create_test_feed_cache : FeedCache
  config = Config.from_yaml("cache_dir: #{File.join(Dir.tempdir, "qh_test_#{Process.pid}_#{Random.rand(10000)}")}")
  db_service = DatabaseService.new(config)
  FeedCache.new(config, db_service)
end

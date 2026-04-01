require "./api_base_controller"

class QuickHeadlines::Controllers::ClusterController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/clusters")]
  def clusters(request : ATH::Request) : QuickHeadlines::DTOs::ClustersResponse
    clusters = clustering_service.get_all_clusters_from_db

    cluster_responses = clusters.map { |cluster| QuickHeadlines::DTOs::ClusterResponse.from_entity(cluster) }

    QuickHeadlines::DTOs::ClustersResponse.new(
      clusters: cluster_responses,
      total_count: cluster_responses.size
    )
  end

  @[ARTA::Get(path: "/api/clusters/{id}/items")]
  def cluster_items(request : ATH::Request, id : String) : ClusterItemsResponse
    cluster_id = id.to_i64?

    if cluster_id.nil?
      return ClusterItemsResponse.new(
        cluster_id: id,
        items: [] of StoryResponse
      )
    end

    cache = @feed_cache
    db_items = cache.get_cluster_items_full(cluster_id)

    items = db_items.map do |item|
      StoryResponse.new(
        id: item[:id].to_s,
        title: item[:title],
        link: item[:link],
        pub_date: item[:pub_date].try(&.to_unix_ms),
        feed_title: item[:feed_title],
        feed_url: item[:feed_url],
        feed_link: "",
        favicon: item[:favicon],
        favicon_data: item[:favicon],
        header_color: item[:header_color]
      )
    end

    ClusterItemsResponse.new(
      cluster_id: id,
      items: items
    )
  end
end
require "./api_base_controller"

class QuickHeadlines::Controllers::ClusterController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/clusters")]
  def clusters(request : AHTTP::Request) : QuickHeadlines::DTOs::ClustersResponse
    check_rate_limit!(request, "api_clusters", 120, 60)

    clustering_service.get_cluster_responses
  end

  @[ARTA::Get(path: "/api/clusters/{id}/items")]
  def cluster_items(request : AHTTP::Request, id : String) : QuickHeadlines::DTOs::ClusterItemsResponse
    check_rate_limit!(request, "api_cluster_items", 120, 60)

    clustering_service.get_cluster_items_response(id, @feed_cache)
  end
end

require "./api_base_controller"

class QuickHeadlines::Controllers::ClusterController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/clusters")]
  def clusters(request : ATH::Request) : QuickHeadlines::DTOs::ClustersResponse
    clustering_service.get_cluster_responses
  end

  @[ARTA::Get(path: "/api/clusters/{id}/items")]
  def cluster_items(request : ATH::Request, id : String) : QuickHeadlines::DTOs::ClusterItemsResponse
    clustering_service.get_cluster_items_response(id, @feed_cache)
  end
end

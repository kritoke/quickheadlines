require "./api_base_controller"
require "../dtos/content_response"

class QuickHeadlines::Controllers::ContentController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/content")]
  def get_content(request : AHTTP::Request) : QuickHeadlines::DTOs::ContentResponse
    check_rate_limit!(request, "api_content", 120, 60)

    item_link = request.query_params["link"]?
    if item_link.nil? || item_link.empty?
      return QuickHeadlines::DTOs::ContentResponse.new(error: "Missing link parameter")
    end

    content_service = QuickHeadlines::Services::ContentService.instance
    content = content_service.get_content(item_link)

    unless content
      return QuickHeadlines::DTOs::ContentResponse.new(error: "Content not found")
    end

    QuickHeadlines::DTOs::ContentResponse.new(content: content, content_type: "html")
  end
end

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
    article = content_service.get_article(item_link)

    unless article
      return QuickHeadlines::DTOs::ContentResponse.new(
        error: "Full article not available. Content is fetched from RSS feeds which typically contain only summaries, not full articles.",
        is_summary: false,
        article_url: item_link
      )
    end

    # Check if the stored content is a summary (short or has summary patterns)
    is_summary = article.content.size < 500 ||
                 article.content =~ /read more|read full|subscribe|click here|sorry.*content/i

    if is_summary
      return QuickHeadlines::DTOs::ContentResponse.new(
        content: article.content,
        content_type: article.content_type,
        is_summary: true,
        article_url: item_link
      )
    end

    QuickHeadlines::DTOs::ContentResponse.new(
      content: article.content,
      content_type: article.content_type,
      is_summary: false,
      article_url: item_link
    )
  end
end

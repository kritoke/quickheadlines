require "db"
require "../services/database_service"
require "./repository_base"

module QuickHeadlines::Repositories
  @[ADI::Register]
  class StoryRepository < RepositoryBase
    def find_timeline_items(limit : Int32, offset : Int32, days_back : Int32?, allowed_feed_urls : Array(String) = [] of String) : Array(QuickHeadlines::Domain::TimelineEntry)
      items = [] of QuickHeadlines::Domain::TimelineEntry

      feed_filter_clause = build_feed_filter(allowed_feed_urls)
      feed_filter_values = feed_filter_values(allowed_feed_urls)

      cutoff_value = days_back ? Time.utc - days_back.days : nil

      query = <<-SQL
        WITH cluster_info AS (
          SELECT
            cluster_id,
            MIN(id) as representative_id,
            COUNT(*) as cluster_size
          FROM items
          WHERE cluster_id IS NOT NULL
          AND pub_date >= ?
          GROUP BY cluster_id
        )
        SELECT
          i.id,
          i.title,
          i.link,
          i.pub_date,
          f.title as feed_title,
          f.url as feed_url,
          f.site_link as feed_link,
          f.favicon,
          f.header_color,
          f.header_text_color,
          i.cluster_id,
          CASE WHEN i.cluster_id IS NULL OR i.id = ci.representative_id THEN 1 ELSE 0 END as is_representative,
          COALESCE(ci.cluster_size, 0) as cluster_size,
          i.comment_url,
          i.commentary_url
        FROM items i
        JOIN feeds f ON i.feed_id = f.id
        LEFT JOIN cluster_info ci ON i.cluster_id = ci.cluster_id
        WHERE (i.pub_date IS NULL OR i.pub_date <= datetime('now', '+1 day'))
        AND (i.cluster_id IS NULL OR i.id = ci.representative_id)
        AND i.pub_date >= ?
        #{feed_filter_clause}
        ORDER BY COALESCE(i.pub_date, '1970-01-01 00:00:00') DESC, i.id DESC
        LIMIT ? OFFSET ?
        SQL

      query_args = [cutoff_value, cutoff_value, *feed_filter_values, limit, offset]

      db.query(query, args: query_args) do |rows|
        rows.each do
          id = rows.read(Int64)
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          feed_title = rows.read(String)
          feed_url = rows.read(String)
          feed_link = rows.read(String?)
          favicon = rows.read(String?)
          header_color = rows.read(String?)
          header_text_color = rows.read(String?)
          cluster_id = rows.read(Int64?)
          is_representative = rows.read(Int32) == 1
          cluster_size = rows.read(Int32)
          comment_url = rows.read(String?)
          commentary_url = rows.read(String?)

          pub_date = parse_db_time(pub_date_str)

          items << QuickHeadlines::Domain::TimelineEntry.new(
            id: id,
            title: title,
            link: link,
            pub_date: pub_date,
            feed_title: feed_title,
            feed_url: feed_url,
            feed_link: feed_link || "",
            favicon: favicon,
            header_color: header_color,
            header_text_color: header_text_color,
            cluster_id: cluster_id,
            representative: is_representative,
            cluster_size: cluster_size,
            comment_url: comment_url,
            commentary_url: commentary_url
          )
        end
      end

      items
    end

    def count_timeline_items(days_back : Int32?, allowed_feed_urls : Array(String) = [] of String) : Int32
      cutoff_value = days_back ? Time.utc - days_back.days : nil
      feed_filter_clause = build_feed_filter(allowed_feed_urls)
      feed_filter_values = feed_filter_values(allowed_feed_urls)

      query = <<-SQL
        WITH cluster_info AS (
          SELECT
            cluster_id,
            MIN(id) as representative_id,
            COUNT(*) as cluster_size
          FROM items
          WHERE cluster_id IS NOT NULL
          AND pub_date >= ?
          GROUP BY cluster_id
        )
        SELECT COUNT(*)
        FROM items i
        JOIN feeds f ON i.feed_id = f.id
        LEFT JOIN cluster_info ci ON i.cluster_id = ci.cluster_id
        WHERE (i.pub_date IS NULL OR i.pub_date <= datetime('now', '+1 day'))
        AND (i.cluster_id IS NULL OR i.id = ci.representative_id)
        AND i.pub_date >= ?
        #{feed_filter_clause}
        SQL

      query_args = [cutoff_value, cutoff_value, *feed_filter_values]

      db.query_one(query, args: query_args, as: Int64).to_i
    end

    private def build_feed_filter(allowed_feed_urls : Array(String)) : String
      return "" if allowed_feed_urls.empty?

      placeholders = (1..allowed_feed_urls.size).map { |_| "?" }.join(", ")
      "AND f.url IN (#{placeholders})"
    end

    private def feed_filter_values(allowed_feed_urls : Array(String)) : Array(String)
      allowed_feed_urls
    end
  end
end

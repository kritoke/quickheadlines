require "db"
require "../services/database_service"

module QuickHeadlines::Repositories
  @[ADI::Register]
  class StoryRepository
    @db : DB::Database

    def initialize(db_or_service : DatabaseService | DB::Database)
      @db = case db_or_service
            when DatabaseService then db_or_service.db
            else                      db_or_service
            end
    end

    private def db : DB::Database
      @db
    end

    def find_all(limit : Int32 = 100, offset : Int32 = 0) : Array(QuickHeadlines::Entities::Story)
      stories = [] of QuickHeadlines::Entities::Story

      db.query(<<-SQL, limit, offset) do |rows|
        SELECT i.id, i.title, i.link, i.pub_date, f.title as feed_title, f.url as feed_url, f.site_link as feed_link, f.favicon, f.header_color
         FROM items i
         JOIN feeds f ON i.feed_id = f.id
         ORDER BY COALESCE(i.pub_date, '1970-01-01 00:00:00') DESC, i.id DESC
         LIMIT ? OFFSET ?
        SQL
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

          stories << build_story(id, title, link, pub_date_str, feed_title, feed_url, feed_link, favicon, header_color)
        end
      end

      stories
    end

    def find_by_id(id : Int64) : QuickHeadlines::Entities::Story?
      db.query_one?(<<-SQL, id) do |row|
        SELECT i.id, i.title, i.link, i.pub_date, f.title as feed_title, f.url as feed_url, f.site_link as feed_link, f.favicon, f.header_color
         FROM items i
         JOIN feeds f ON i.feed_id = f.id
         WHERE i.id = ?
        SQL
        id = row.read(Int64)
        title = row.read(String)
        link = row.read(String)
        pub_date_str = row.read(String?)
        feed_title = row.read(String)
        feed_url = row.read(String)
        feed_link = row.read(String?)
        favicon = row.read(String?)
        header_color = row.read(String?)

        build_story(id, title, link, pub_date_str, feed_title, feed_url, feed_link, favicon, header_color)
      end
    end

    def find_by_feed(feed_id : Int64, limit : Int32 = 20, offset : Int32 = 0) : Array(QuickHeadlines::Entities::Story)
      stories = [] of QuickHeadlines::Entities::Story

      db.query(<<-SQL, feed_id, limit, offset) do |rows|
        SELECT i.id, i.title, i.link, i.pub_date, f.title as feed_title, f.url as feed_url, f.site_link as feed_link, f.favicon, f.header_color
         FROM items i
         JOIN feeds f ON i.feed_id = f.id
         WHERE f.id = ?
         ORDER BY COALESCE(i.pub_date, '1970-01-01 00:00:00') DESC, i.id DESC
         LIMIT ? OFFSET ?
        SQL
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

          stories << build_story(id, title, link, pub_date_str, feed_title, feed_url, feed_link, favicon, header_color)
        end
      end

      stories
    end

    def save(story : QuickHeadlines::Entities::Story) : QuickHeadlines::Entities::Story
      feed = find_feed_by_url(story.feed_url)
      return story unless feed

      feed_id = feed.id.to_i64

      existing = db.query_one?(
        "SELECT id FROM items WHERE feed_id = ? AND link = ?",
        feed_id, story.link,
        as: Int64?
      )

      if existing.nil?
        pub_date_str = story.pub_date.try(&.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT))

        db.exec(
          "INSERT INTO items (feed_id, title, link, pub_date) VALUES (?, ?, ?, ?)",
          feed_id,
          story.title,
          story.link,
          pub_date_str
        )
      end

      story
    end

    def find_timeline_items(limit : Int32, offset : Int32, days_back : Int32?, allowed_feed_urls : Array(String) = [] of String) : Array(QuickHeadlines::Domain::TimelineEntry)
      items = [] of QuickHeadlines::Domain::TimelineEntry

      cutoff_clause = days_back ? "AND i.pub_date >= ?" : ""
      feed_filter_clause = build_feed_filter_clause(allowed_feed_urls)

      cutoff_value = days_back ? Time.local - days_back.days : nil
      feed_filter_values = build_feed_filter_values(allowed_feed_urls)

      # Use CTE to pre-compute cluster representatives and sizes (eliminates per-row subqueries)
      query = <<-SQL
        WITH cluster_info AS (
          SELECT
            cluster_id,
            MIN(id) as representative_id,
            COUNT(*) as cluster_size
          FROM items
          WHERE cluster_id IS NOT NULL
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
          COALESCE(ci.cluster_size, 0) as cluster_size
        FROM items i
        JOIN feeds f ON i.feed_id = f.id
        LEFT JOIN cluster_info ci ON i.cluster_id = ci.cluster_id
        WHERE (i.pub_date IS NULL OR i.pub_date <= datetime('now', '+1 day'))
        AND (i.cluster_id IS NULL OR i.id = ci.representative_id)
        #{cutoff_clause}
        #{feed_filter_clause}
        ORDER BY COALESCE(i.pub_date, '1970-01-01 00:00:00') DESC, i.id DESC
        LIMIT ? OFFSET ?
        SQL

      if cutoff_value && !feed_filter_values.empty?
        query_args = [cutoff_value, *feed_filter_values, limit, offset]
      elsif cutoff_value
        query_args = [cutoff_value, limit, offset]
      elsif !feed_filter_values.empty?
        query_args = [*feed_filter_values, limit, offset]
      else
        query_args = [limit, offset]
      end

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

          pub_date = pub_date_str.try { |str| Time.parse(str, QuickHeadlines::Constants::DB_TIME_FORMAT, Time::Location::UTC) }

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
            cluster_size: cluster_size
          )
        end
      end

      items
    end

    def count_timeline_items(days_back : Int32?, allowed_feed_urls : Array(String) = [] of String) : Int32
      cutoff_clause = days_back ? "AND i.pub_date >= ?" : ""
      feed_filter_clause = build_feed_filter_clause(allowed_feed_urls)

      cutoff_value = days_back ? Time.local - days_back.days : nil
      feed_filter_values = build_feed_filter_values(allowed_feed_urls)

      query = "SELECT COUNT(*) FROM items i JOIN feeds f ON i.feed_id = f.id WHERE 1=1 #{cutoff_clause} #{feed_filter_clause}"

      if cutoff_value && !feed_filter_values.empty?
        query_args = [cutoff_value, *feed_filter_values]
      elsif cutoff_value
        query_args = [cutoff_value]
      elsif !feed_filter_values.empty?
        query_args = feed_filter_values
      else
        query_args = [] of String
      end

      db.query_one(query, args: query_args, as: Int64).to_i
    end

    def deduplicate(feed_id : Int64, title : String) : Bool
      result = db.query_one?(
        "SELECT COUNT(*) FROM items WHERE feed_id = ? AND title = ?",
        feed_id, title,
        as: Int64
      )
      (result || 0) > 0
    end

    private def build_feed_filter_clause(allowed_feed_urls : Array(String)) : String
      return "" if allowed_feed_urls.empty?

      placeholders = (1..allowed_feed_urls.size).map { |_| "?" }.join(", ")
      "AND f.url IN (#{placeholders})"
    end

    private def build_feed_filter_values(allowed_feed_urls : Array(String)) : Array(String)
      allowed_feed_urls
    end

    private def find_feed_by_url(url : String) : QuickHeadlines::Entities::Feed?
      db.query_one?(
        "SELECT id, url, title, site_link, header_color, header_text_color, favicon, favicon_data FROM feeds WHERE url = ?",
        url
      ) do |row|
        id = row.read(Int64)
        url = row.read(String)
        title = row.read(String)
        site_link = row.read(String?)
        header_color = row.read(String?)
        header_text_color = row.read(String?)
        favicon = row.read(String?)
        favicon_data = row.read(String?)

        QuickHeadlines::Entities::Feed.new(
          id: id.to_s,
          title: title,
          url: url,
          site_link: site_link || "",
          header_color: header_color,
          header_text_color: header_text_color,
          favicon: favicon,
          favicon_data: favicon_data
        )
      end
    end

    private def build_story(id : Int64, title : String, link : String, pub_date_str : String?, feed_title : String, feed_url : String, feed_link : String?, favicon : String?, header_color : String?) : QuickHeadlines::Entities::Story
      pub_date = pub_date_str.try { |str| Time.parse(str, QuickHeadlines::Constants::DB_TIME_FORMAT, Time::Location::UTC) }
      QuickHeadlines::Entities::Story.new(
        id: id.to_s,
        title: title,
        link: link,
        pub_date: pub_date,
        feed_title: feed_title,
        feed_url: feed_url,
        feed_link: feed_link || "",
        favicon: favicon,
        favicon_data: favicon,
        header_color: header_color
      )
    end
  end

end

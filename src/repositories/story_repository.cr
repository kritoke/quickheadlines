require "db"

module Quickheadlines::Repositories
  class StoryRepository
    @db : DB::Database

    def initialize(@db : DB::Database)
    end

    def find_all(limit : Int32 = 100, offset : Int32 = 0) : Array(Quickheadlines::Entities::Story)
      stories = [] of Quickheadlines::Entities::Story

      @db.query(
        "SELECT i.id, i.title, i.link, i.pub_date, f.title as feed_title, f.url as feed_url, f.site_link as feed_link, f.favicon, f.header_color
         FROM items i
         JOIN feeds f ON i.feed_id = f.id
         ORDER BY COALESCE(i.pub_date, '1970-01-01 00:00:00') DESC, i.id DESC
         LIMIT ? OFFSET ?",
        limit, offset
      ) do |rows|
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

          pub_date = pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

          stories << Quickheadlines::Entities::Story.new(
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

      stories
    end

    def find_by_id(id : Int64) : Quickheadlines::Entities::Story?
      @db.query_one?(
        "SELECT i.id, i.title, i.link, i.pub_date, f.title as feed_title, f.url as feed_url, f.site_link as feed_link, f.favicon, f.header_color
         FROM items i
         JOIN feeds f ON i.feed_id = f.id
         WHERE i.id = ?",
        id
      ) do |row|
        id = row.read(Int64)
        title = row.read(String)
        link = row.read(String)
        pub_date_str = row.read(String?)
        feed_title = row.read(String)
        feed_url = row.read(String)
        feed_link = row.read(String?)
        favicon = row.read(String?)
        header_color = row.read(String?)

        pub_date = pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

        Quickheadlines::Entities::Story.new(
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

    def find_by_feed(feed_id : Int64, limit : Int32 = 20, offset : Int32 = 0) : Array(Quickheadlines::Entities::Story)
      stories = [] of Quickheadlines::Entities::Story

      @db.query(
        "SELECT i.id, i.title, i.link, i.pub_date, f.title as feed_title, f.url as feed_url, f.site_link as feed_link, f.favicon, f.header_color
         FROM items i
         JOIN feeds f ON i.feed_id = f.id
         WHERE f.id = ?
         ORDER BY COALESCE(i.pub_date, '1970-01-01 00:00:00') DESC, i.id DESC
         LIMIT ? OFFSET ?",
        feed_id, limit, offset
      ) do |rows|
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

          pub_date = pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

          stories << Quickheadlines::Entities::Story.new(
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

      stories
    end

    def save(story : Quickheadlines::Entities::Story) : Quickheadlines::Entities::Story
      feed = find_feed_by_url(story.feed_url)
      return story unless feed

      feed_id = feed.id.to_i64

      existing = @db.query_one?(
        "SELECT id FROM items WHERE feed_id = ? AND link = ?",
        feed_id, story.link,
        as: Int64?
      )

      if existing.nil?
        pub_date_str = story.pub_date.try(&.to_s("%Y-%m-%d %H:%M:%S"))

        @db.exec(
          "INSERT INTO items (feed_id, title, link, pub_date) VALUES (?, ?, ?, ?)",
          feed_id,
          story.title,
          story.link,
          pub_date_str
        )
      end

      story
    end

    def find_timeline_items(limit : Int32, offset : Int32, days_back : Int32?) : Array(TimelineItem)
      items = [] of TimelineItem

      cutoff_clause = days_back ? "AND i.pub_date >= ?" : ""

      query = <<-SQL
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
          CASE WHEN i.id = (SELECT MIN(id) FROM items WHERE cluster_id = i.cluster_id AND cluster_id IS NOT NULL) THEN 1 ELSE 0 END as is_representative,
          (SELECT COUNT(*) FROM items WHERE cluster_id = i.cluster_id AND cluster_id IS NOT NULL) as cluster_size
        FROM items i
        JOIN feeds f ON i.feed_id = f.id
        AND (i.pub_date IS NULL OR i.pub_date <= datetime('now', '+1 day'))
        #{cutoff_clause}
        ORDER BY COALESCE(i.pub_date, '1970-01-01 00:00:00') DESC, i.id DESC
        LIMIT ? OFFSET ?
        SQL

      query_args = days_back ? [Time.local - days_back.days, limit, offset] : [limit, offset]

      @db.query(query, args: query_args) do |rows|
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

          pub_date = pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

          items << TimelineItem.new(
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
            is_representative: is_representative,
            cluster_size: cluster_size
          )
        end
      end

      items
    end

    def count_timeline_items(days_back : Int32?) : Int32
      if days_back
        cutoff_date = Time.local - days_back.days
        @db.query_one("SELECT COUNT(*) FROM items WHERE pub_date >= ?", cutoff_date, as: Int64)
      else
        @db.query_one("SELECT COUNT(*) FROM items", as: Int64)
      end.to_i
    end

    def deduplicate(feed_id : Int64, title : String) : Bool
      result = @db.query_one?(
        "SELECT COUNT(*) FROM items WHERE feed_id = ? AND title = ?",
        feed_id, title,
        as: Int64
      )
      result > 0
    end

    private def find_feed_by_url(url : String) : Quickheadlines::Entities::Feed?
      @db.query_one?(
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

        Quickheadlines::Entities::Feed.new(
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
  end

  struct TimelineItem
    property id : Int64
    property title : String
    property link : String
    property pub_date : Time?
    property feed_title : String
    property feed_url : String
    property feed_link : String
    property favicon : String?
    property header_color : String?
    property header_text_color : String?
    property cluster_id : Int64?
    property is_representative : Bool
    property cluster_size : Int32

    def initialize(
      @id,
      @title,
      @link,
      @pub_date,
      @feed_title,
      @feed_url,
      @feed_link,
      @favicon,
      @header_color,
      @header_text_color,
      @cluster_id,
      @is_representative,
      @cluster_size
    )
    end
  end
end

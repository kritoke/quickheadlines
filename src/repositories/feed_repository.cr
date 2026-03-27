require "db"
require "../models"
require "../result"
require "../errors"

module Quickheadlines::Repositories
  class FeedRepository
    @db : DB::Database

    def initialize(@db : DB::Database)
    end

    def find_all : Array(Quickheadlines::Entities::Feed)
      feeds = [] of Quickheadlines::Entities::Feed

      @db.query("SELECT id, url, title, site_link, header_color, header_text_color, favicon, favicon_data FROM feeds ORDER BY title") do |rows|
        rows.each do
          id = rows.read(Int64)
          url = rows.read(String)
          title = rows.read(String)
          site_link = rows.read(String?)
          header_color = rows.read(String?)
          header_text_color = rows.read(String?)
          favicon = rows.read(String?)
          favicon_data = rows.read(String?)

          feeds << Quickheadlines::Entities::Feed.new(
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

      feeds
    end

    def find_all_urls : Array(String)
      urls = [] of String
      @db.query("SELECT url FROM feeds") do |rows|
        rows.each do
          urls << rows.read(String)
        end
      end
      urls
    end

    def count_all : Int32
      result = @db.query_one?("SELECT COUNT(*) FROM feeds", as: Int64)
      result ? result.to_i : 0
    end

    def find_last_fetched_time(url : String) : Time?
      result = @db.query_one?("SELECT last_fetched FROM feeds WHERE url = ?", url, as: String?)
      return unless result
      Time.parse(result, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
    end

    def find_last_fetched_time_result(url : String) : TimeResult
      result = @db.query_one?("SELECT last_fetched FROM feeds WHERE url = ?", url, as: String?)
      return TimeResult.failure(RepositoryError::NotFound) unless result
      TimeResult.success(Time.parse(result, "%Y-%m-%d %H:%M:%S", Time::Location::UTC))
    rescue
      TimeResult.failure(RepositoryError::DatabaseError)
    end

    def find_by_url(url : String) : Quickheadlines::Entities::Feed?
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

    def find_by_url_result(url : String) : Result(Quickheadlines::Entities::Feed?, RepositoryError)
      result = find_by_url(url)
      return Result(Quickheadlines::Entities::Feed?, RepositoryError).failure(RepositoryError::NotFound) unless result
      Result(Quickheadlines::Entities::Feed?, RepositoryError).success(result)
    rescue
      Result(Quickheadlines::Entities::Feed?, RepositoryError).failure(RepositoryError::DatabaseError)
    end

    def find_by_pattern(pattern : String) : Quickheadlines::Entities::Feed?
      normalized = pattern.strip.rstrip('/')
        .gsub(/\/rss(\.xml)?$/i, "")
        .gsub(/\/feed(\.xml)?$/i, "")

      find_by_url(normalized) || find_by_url("#{normalized}/") || find_by_url("#{normalized}/rss")
    end

    def find_by_pattern_result(pattern : String) : Result(Quickheadlines::Entities::Feed?, RepositoryError)
      result = find_by_pattern(pattern)
      return Result(Quickheadlines::Entities::Feed?, RepositoryError).failure(RepositoryError::NotFound) unless result
      Result(Quickheadlines::Entities::Feed?, RepositoryError).success(result)
    rescue
      Result(Quickheadlines::Entities::Feed?, RepositoryError).failure(RepositoryError::DatabaseError)
    end

    def save(feed : Quickheadlines::Entities::Feed) : Quickheadlines::Entities::Feed
      existing = find_by_url(feed.url)

      if existing
        @db.exec(
          "UPDATE feeds SET title = ?, site_link = ?, header_color = ?, header_text_color = ?, favicon = ?, favicon_data = ? WHERE url = ?",
          feed.title,
          feed.site_link,
          feed.header_color,
          feed.header_text_color,
          feed.favicon,
          feed.favicon_data,
          feed.url
        )
      else
        @db.exec(
          "INSERT INTO feeds (url, title, site_link, header_color, header_text_color, favicon, favicon_data, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
          feed.url,
          feed.title,
          feed.site_link,
          feed.header_color,
          feed.header_text_color,
          feed.favicon,
          feed.favicon_data,
          Time.utc.to_s("%Y-%m-%d %H:%M:%S")
        )
      end

      feed
    end

    def update_last_fetched(url : String, time : Time = Time.utc) : Nil
      @db.exec(
        "UPDATE feeds SET last_fetched = ? WHERE url = ?",
        time.to_s("%Y-%m-%d %H:%M:%S"),
        url
      )
    end

    def update_header_colors(url : String, bg : String?, text : String?) : Nil
      if bg || text
        existing_bg = @db.query_one?("SELECT header_color FROM feeds WHERE url = ?", url, as: String?)
        existing_text = @db.query_one?("SELECT header_text_color FROM feeds WHERE url = ?", url, as: String?)

        bg_to_save = bg || existing_bg
        text_to_save = text || existing_text

        @db.exec(
          "UPDATE feeds SET header_color = ?, header_text_color = ? WHERE url = ?",
          bg_to_save,
          text_to_save,
          url
        )
      end
    end

    def delete_by_url(url : String) : Nil
      @db.exec("DELETE FROM items WHERE feed_id IN (SELECT id FROM feeds WHERE url = ?)", url)
      @db.exec("DELETE FROM feeds WHERE url = ?", url)
    end

    def count_items(url : String) : Int32
      result = @db.query_one?(
        "SELECT COUNT(*) FROM items JOIN feeds ON items.feed_id = feeds.id WHERE feeds.url = ?",
        url,
        as: Int64
      )
      result ? result.to_i : 0
    end

    def upsert_with_items(feed_data : FeedData) : Nil
      @db.exec("BEGIN TRANSACTION")

      begin
        feed_id = upsert_feed(feed_data)
        insert_items(feed_id, feed_data.items)
        @db.exec("COMMIT")
        STDERR.puts "[FeedRepository] Upserted feed: #{feed_data.title} (#{feed_data.url}) with #{feed_data.items.size} items"
      rescue ex
        STDERR.puts "[FeedRepository ERROR] Failed to upsert feed #{feed_data.title}: #{ex.message}"
        @db.exec("ROLLBACK")
        raise ex
      end
    end

    private def upsert_feed(feed_data : FeedData) : Int64
      result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", feed_data.url, as: {Int64})

      if result
        update_feed(result, feed_data)
      else
        insert_feed(feed_data)
      end
    end

    private def update_feed(feed_id : Int64, feed_data : FeedData) : Int64
      existing_color = @db.query_one?("SELECT header_color FROM feeds WHERE id = ?", feed_id, as: {String?})
      existing_text_color = @db.query_one?("SELECT header_text_color FROM feeds WHERE id = ?", feed_id, as: {String?})
      existing_theme = @db.query_one?("SELECT header_theme_colors FROM feeds WHERE id = ?", feed_id, as: {String?})

      header_color_to_save = feed_data.header_color.nil? ? existing_color : feed_data.header_color
      header_text_color_to_save = feed_data.header_text_color.nil? ? existing_text_color : feed_data.header_text_color
      header_theme_to_save = feed_data.header_theme_colors.nil? ? existing_theme : feed_data.header_theme_colors

      @db.exec(
        "UPDATE feeds SET title = ?, site_link = ?, header_color = ?, header_text_color = ?, header_theme_colors = ?, etag = ?, last_modified = ?, favicon = ?, favicon_data = ?, last_fetched = ? WHERE id = ?",
        feed_data.title,
        feed_data.site_link,
        header_color_to_save,
        header_text_color_to_save,
        header_theme_to_save,
        feed_data.etag,
        feed_data.last_modified,
        feed_data.favicon,
        feed_data.favicon_data,
        Time.utc.to_s("%Y-%m-%d %H:%M:%S"),
        feed_id
      )
      feed_id
    end

    private def insert_feed(feed_data : FeedData) : Int64
      @db.exec(
        "INSERT INTO feeds (url, title, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        feed_data.url,
        feed_data.title,
        feed_data.site_link,
        feed_data.header_color,
        feed_data.header_text_color,
        feed_data.header_theme_colors,
        feed_data.etag,
        feed_data.last_modified,
        feed_data.favicon,
        feed_data.favicon_data,
        Time.utc.to_s("%Y-%m-%d %H:%M:%S")
      )
      @db.scalar("SELECT last_insert_rowid()").as(Int64)
    end

    private def insert_items(feed_id : Int64, items : Array(Item)) : Nil
      existing_titles = @db.query_all("SELECT title FROM items WHERE feed_id = ?", feed_id, as: String).to_set

      items.each_with_index do |item, index|
        next if existing_titles.includes?(item.title)

        pub_date_str = item.pub_date.try(&.to_s("%Y-%m-%d %H:%M:%S"))

        @db.exec(
          "INSERT OR IGNORE INTO items (feed_id, title, link, pub_date, version, position) VALUES (?, ?, ?, ?, ?, ?)",
          feed_id,
          item.title,
          item.link,
          pub_date_str,
          item.version,
          index
        )

        existing_titles << item.title

        @db.exec(
          "UPDATE items SET pub_date = ?, position = ? WHERE feed_id = ? AND link = ?",
          pub_date_str,
          index,
          feed_id,
          item.link
        )
      end
    end

    def find_with_items(url : String) : FeedData?
      feed_result = @db.query_one?(
        "SELECT title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?",
        url
      ) do |row|
        {
          title:               row.read(String),
          url:                 row.read(String),
          site_link:           row.read(String),
          header_color:        row.read(String?),
          header_text_color:   row.read(String?),
          header_theme_colors: row.read(String?),
          etag:                row.read(String?),
          last_modified:       row.read(String?),
          favicon:             row.read(String?),
          favicon_data:        row.read(String?),
        }
      end
      return unless feed_result

      feed_id_result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", url, as: Int64)
      return unless feed_id_result
      feed_id = feed_id_result

      items = [] of Item
      @db.query("SELECT title, link, pub_date, version FROM items WHERE feed_id = ? AND (pub_date IS NULL OR pub_date <= datetime('now', '+1 day')) ORDER BY pub_date DESC", feed_id) do |rows|
        rows.each do
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          version = rows.read(String?)

          pub_date = pub_date_str.try { |date_str| Time.parse(date_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }
          items << Item.new(title, link, pub_date, version, nil, nil)
        end
      end

      FeedData.new(
        feed_result[:title],
        feed_result[:url],
        feed_result[:site_link],
        feed_result[:header_color],
        feed_result[:header_text_color],
        items,
        feed_result[:etag],
        feed_result[:last_modified],
        feed_result[:favicon],
        feed_result[:favicon_data],
        nil,
        feed_result[:header_theme_colors]
      )
    end

    def find_with_items_result(url : String) : FeedDataResult
      result = find_with_items(url)
      return FeedDataResult.failure(RepositoryError::NotFound) unless result
      FeedDataResult.success(result)
    rescue
      FeedDataResult.failure(RepositoryError::DatabaseError)
    end

    def find_with_items_slice(url : String, limit : Int32, offset : Int32) : FeedData?
      feed_result = @db.query_one?(
        "SELECT title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?",
        url
      ) do |row|
        {
          title:               row.read(String),
          url:                 row.read(String),
          site_link:           row.read(String),
          header_color:        row.read(String?),
          header_text_color:   row.read(String?),
          header_theme_colors: row.read(String?),
          etag:                row.read(String?),
          last_modified:       row.read(String?),
          favicon:             row.read(String?),
          favicon_data:        row.read(String?),
        }
      end
      return unless feed_result

      items = [] of Item
      query = "SELECT title, link, pub_date, version FROM items WHERE feed_id = (SELECT id FROM feeds WHERE url = ?) AND (pub_date IS NULL OR pub_date <= datetime('now', '+1 day')) ORDER BY pub_date DESC LIMIT ? OFFSET ?"

      @db.query(query, url, limit, offset) do |rows|
        rows.each do
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          version = rows.read(String?)

          pub_date = pub_date_str.try { |date_str| Time.parse(date_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }
          items << Item.new(title, link, pub_date, version, nil, nil)
        end
      end

      fd = FeedData.new(
        feed_result[:title],
        feed_result[:url],
        feed_result[:site_link],
        feed_result[:header_color],
        feed_result[:header_text_color],
        items,
        feed_result[:etag],
        feed_result[:last_modified],
        feed_result[:favicon],
        feed_result[:favicon_data]
      )
      fd.header_theme_colors = feed_result[:header_theme_colors] if feed_result[:header_theme_colors]
      fd
    end

    def find_with_items_slice_result(url : String, limit : Int32, offset : Int32) : FeedDataResult
      result = find_with_items_slice(url, limit, offset)
      return FeedDataResult.failure(RepositoryError::NotFound) unless result
      FeedDataResult.success(result)
    rescue
      FeedDataResult.failure(RepositoryError::DatabaseError)
    end
  end
end

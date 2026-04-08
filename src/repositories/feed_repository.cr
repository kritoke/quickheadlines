require "db"
require "../models"
require "../result"
require "../errors"
require "../services/database_service"

module QuickHeadlines::Repositories
  @[ADI::Register]
  class FeedRepository
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

    private def read_feed_entity(rows : DB::ResultSet) : QuickHeadlines::Entities::Feed
      id = rows.read(Int64)
      url = rows.read(String)
      title = rows.read(String)
      site_link = rows.read(String?)
      header_color = rows.read(String?)
      header_text_color = rows.read(String?)
      favicon = rows.read(String?)
      favicon_data = rows.read(String?)

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

    private record FeedRowData,
      title : String,
      url : String,
      site_link : String,
      header_color : String?,
      header_text_color : String?,
      header_theme_colors : String?,
      etag : String?,
      last_modified : String?,
      favicon : String?,
      favicon_data : String? do
      def to_feed_data(items : Array(Item)) : FeedData
        FeedData.new(
          title,
          url,
          site_link,
          header_color,
          header_text_color,
          items,
          etag,
          last_modified,
          favicon,
          favicon_data,
          nil,
          header_theme_colors
        )
      end
    end

    private def read_feed_row(rows : DB::ResultSet) : FeedRowData
      FeedRowData.new(
        rows.read(String),
        rows.read(String),
        rows.read(String),
        rows.read(String?),
        rows.read(String?),
        rows.read(String?),
        rows.read(String?),
        rows.read(String?),
        rows.read(String?),
        rows.read(String?)
      )
    end

    private def read_item(rows : DB::ResultSet) : Item
      title = rows.read(String)
      link = rows.read(String)
      pub_date_str = rows.read(String?)
      version = rows.read(String?)
      comment_url = rows.read(String?)
      commentary_url = rows.read(String?)

      pub_date = pub_date_str.try do |date_str|
        begin
          Time.parse(date_str, QuickHeadlines::Constants::DB_TIME_FORMAT, Time::Location::UTC)
        rescue Time::Format::Error
          nil
        end
      end
      Item.new(title, link, pub_date, version, comment_url, commentary_url)
    end

    def find_all : Array(QuickHeadlines::Entities::Feed)
      feeds = [] of QuickHeadlines::Entities::Feed

      db.query("SELECT id, url, title, site_link, header_color, header_text_color, favicon, favicon_data FROM feeds ORDER BY title") do |rows|
        rows.each do
          feeds << read_feed_entity(rows)
        end
      end

      feeds
    end

    def find_all_urls : Array(String)
      urls = [] of String
      db.query("SELECT url FROM feeds") do |rows|
        rows.each do
          urls << rows.read(String)
        end
      end
      urls
    end

    def find_all_feeds_with_items : Hash(String, FeedData)
      feed_rows = [] of {id: Int64, title: String, url: String, site_link: String?, header_color: String?, header_text_color: String?, header_theme_colors: String?, etag: String?, last_modified: String?, favicon: String?, favicon_data: String?}
      feed_id_map = {} of Int64 => FeedRowData

      db.query("SELECT id, title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds ORDER BY title") do |rows|
        rows.each do
          id = rows.read(Int64)
          title = rows.read(String)
          url = rows.read(String)
          site_link = rows.read(String?)
          header_color = rows.read(String?)
          header_text_color = rows.read(String?)
          header_theme_colors = rows.read(String?)
          etag = rows.read(String?)
          last_modified = rows.read(String?)
          favicon = rows.read(String?)
          favicon_data = rows.read(String?)
          fd = FeedRowData.new(title, url, site_link || "", header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data)
          feed_id_map[id] = fd
          feed_rows << {id: id, title: title, url: url, site_link: site_link, header_color: header_color, header_text_color: header_text_color, header_theme_colors: header_theme_colors, etag: etag, last_modified: last_modified, favicon: favicon, favicon_data: favicon_data}
        end
      end

      return {} of String => FeedData if feed_id_map.empty?

      items_by_feed = Hash(Int64, Array(Item)).new { |hash, key| hash[key] = [] of Item }
      db.query("SELECT feed_id, title, link, pub_date, version, comment_url, commentary_url FROM items WHERE (pub_date IS NULL OR pub_date <= datetime('now', '+1 day')) ORDER BY pub_date DESC") do |rows|
        rows.each do
          feed_id = rows.read(Int64)
          next unless feed_id_map.has_key?(feed_id)
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          version = rows.read(String?)
          comment_url = rows.read(String?)
          commentary_url = rows.read(String?)
          pub_date = pub_date_str.try do |date_str|
            begin
              Time.parse(date_str, QuickHeadlines::Constants::DB_TIME_FORMAT, Time::Location::UTC)
            rescue Time::Format::Error
              nil
            end
          end
          items_by_feed[feed_id] << Item.new(title, link, pub_date, version, comment_url, commentary_url)
        end
      end

      result = {} of String => FeedData
      feed_rows.each do |feed_row|
        fd = feed_id_map[feed_row.id]
        items = items_by_feed[feed_row.id]?
        items ||= [] of Item
        result[feed_row.url] = fd.to_feed_data(items)
      end
      result
    end

    def count_all : Int32
      result = db.query_one?("SELECT COUNT(*) FROM feeds", as: Int64)
      result ? result.to_i : 0
    end

    def find_last_fetched_time(url : String) : Time?
      result = db.query_one?("SELECT last_fetched FROM feeds WHERE url = ?", url, as: String?)
      return unless result
      begin
        Time.parse(result, QuickHeadlines::Constants::DB_TIME_FORMAT, Time::Location::UTC)
      rescue Time::Format::Error
        nil
      end
    end

    def find_last_fetched_time_result(url : String) : TimeResult
      result = db.query_one?("SELECT last_fetched FROM feeds WHERE url = ?", url, as: String?)
      return TimeResult.failure(RepositoryError::NotFound) unless result
      begin
        TimeResult.success(Time.parse(result, QuickHeadlines::Constants::DB_TIME_FORMAT, Time::Location::UTC))
      rescue Time::Format::Error
        TimeResult.failure(RepositoryError::DatabaseError)
      end
    end

    def find_by_url(url : String) : QuickHeadlines::Entities::Feed?
      db.query_one?(
        "SELECT id, url, title, site_link, header_color, header_text_color, favicon, favicon_data FROM feeds WHERE url = ?",
        url
      ) do |row|
        read_feed_entity(row)
      end
    end

    def find_by_url_result(url : String) : Result(QuickHeadlines::Entities::Feed?, RepositoryError)
      result = find_by_url(url)
      return Result(QuickHeadlines::Entities::Feed?, RepositoryError).failure(RepositoryError::NotFound) unless result
      Result(QuickHeadlines::Entities::Feed?, RepositoryError).success(result)
    rescue DB::Error
      Result(QuickHeadlines::Entities::Feed?, RepositoryError).failure(RepositoryError::DatabaseError)
    end

    def find_by_pattern(pattern : String) : QuickHeadlines::Entities::Feed?
      normalized = pattern.strip.rstrip('/')
        .gsub(/\/rss(\.xml)?$/i, "")
        .gsub(/\/feed(\.xml)?$/i, "")

      find_by_url(normalized) || find_by_url("#{normalized}/") || find_by_url("#{normalized}/rss")
    end

    def find_by_pattern_result(pattern : String) : Result(QuickHeadlines::Entities::Feed?, RepositoryError)
      result = find_by_pattern(pattern)
      return Result(QuickHeadlines::Entities::Feed?, RepositoryError).failure(RepositoryError::NotFound) unless result
      Result(QuickHeadlines::Entities::Feed?, RepositoryError).success(result)
    rescue DB::Error
      Result(QuickHeadlines::Entities::Feed?, RepositoryError).failure(RepositoryError::DatabaseError)
    end

    def save(feed : QuickHeadlines::Entities::Feed) : QuickHeadlines::Entities::Feed
      existing = find_by_url(feed.url)

      if existing
        db.exec(
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
        db.exec(
          "INSERT INTO feeds (url, title, site_link, header_color, header_text_color, favicon, favicon_data, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
          feed.url,
          feed.title,
          feed.site_link,
          feed.header_color,
          feed.header_text_color,
          feed.favicon,
          feed.favicon_data,
          Time.utc.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)
        )
      end

      feed
    end

    def update_last_fetched(url : String, time : Time = Time.utc) : Nil
      db.exec(
        "UPDATE feeds SET last_fetched = ? WHERE url = ?",
        time.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT),
        url
      )
    end

    def update_header_colors(url : String, bg : String?, text : String?) : Nil
      if bg || text
        existing_bg = db.query_one?("SELECT header_color FROM feeds WHERE url = ?", url, as: String?)
        existing_text = db.query_one?("SELECT header_text_color FROM feeds WHERE url = ?", url, as: String?)

        bg_to_save = bg || existing_bg
        text_to_save = text || existing_text

        db.exec(
          "UPDATE feeds SET header_color = ?, header_text_color = ? WHERE url = ?",
          bg_to_save,
          text_to_save,
          url
        )
      end
    end

    def delete_by_url(url : String) : Nil
      db.exec("DELETE FROM items WHERE feed_id IN (SELECT id FROM feeds WHERE url = ?)", url)
      db.exec("DELETE FROM feeds WHERE url = ?", url)
    end

    def count_items(url : String) : Int32
      result = db.query_one?(
        "SELECT COUNT(*) FROM items JOIN feeds ON items.feed_id = feeds.id WHERE feeds.url = ?",
        url,
        as: Int64
      )
      result ? result.to_i : 0
    end

    def upsert_with_items(feed_data : FeedData) : Nil
      db.transaction do
        feed_id = upsert_feed(feed_data)
        insert_items(feed_id, feed_data.items)
        Log.for("quickheadlines.feed").info { "Upserted feed: #{feed_data.title} (#{feed_data.url}) with #{feed_data.items.size} items" }
      end
    end

    private def upsert_feed(feed_data : FeedData) : Int64
      result = db.query_one?("SELECT id FROM feeds WHERE url = ?", feed_data.url, as: {Int64})

      if result
        update_feed(result, feed_data)
      else
        insert_feed(feed_data)
      end
    end

    private def update_feed(feed_id : Int64, feed_data : FeedData) : Int64
      existing_color = db.query_one?("SELECT header_color FROM feeds WHERE id = ?", feed_id, as: {String?})
      existing_text_color = db.query_one?("SELECT header_text_color FROM feeds WHERE id = ?", feed_id, as: {String?})
      existing_theme = db.query_one?("SELECT header_theme_colors FROM feeds WHERE id = ?", feed_id, as: {String?})

      header_color_to_save = feed_data.header_color.nil? ? existing_color : feed_data.header_color
      header_text_color_to_save = feed_data.header_text_color.nil? ? existing_text_color : feed_data.header_text_color
      header_theme_to_save = feed_data.header_theme_colors.nil? ? existing_theme : feed_data.header_theme_colors

      db.exec(
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
        Time.utc.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT),
        feed_id
      )
      feed_id
    end

    private def insert_feed(feed_data : FeedData) : Int64
      db.exec(
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
        Time.utc.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)
      )
      db.scalar("SELECT last_insert_rowid()").as(Int64)
    end

    private def insert_items(feed_id : Int64, items : Array(Item)) : Nil
      return if items.empty?

      existing_titles = db.query_all("SELECT title FROM items WHERE feed_id = ?", feed_id, as: String).to_set

      new_items = [] of {item: Item, index: Int32}
      existing_items = [] of {item: Item, index: Int32}

      items.each_with_index do |item, index|
        if existing_titles.includes?(item.title)
          existing_items << {item: item, index: index}
        else
          new_items << {item: item, index: index}
          existing_titles << item.title
        end
      end

      if new_items.present?
        batch_insert(new_items, feed_id)
      end

      if existing_items.present?
        batch_update(existing_items, feed_id)
      end
    end

    private def batch_insert(new_items : Array({item: Item, index: Int32}), feed_id : Int64) : Nil
      return if new_items.empty?

      new_items.each_slice(50) do |batch|
        values_clause = batch.map do
          "(?, ?, ?, ?, ?, ?, ?, ?)"
        end.join(", ")
        args = batch.flat_map do |entry|
          item = entry[:item]
          pub_date_str = item.pub_date.try(&.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT))
          [feed_id, item.title, item.link, pub_date_str, item.version, entry[:index], item.comment_url, item.commentary_url]
        end
        db.exec("INSERT OR IGNORE INTO items (feed_id, title, link, pub_date, version, position, comment_url, commentary_url) VALUES #{values_clause}", args: args)
      end
    end

    private def batch_update(existing_items : Array({item: Item, index: Int32}), feed_id : Int64) : Nil
      return if existing_items.empty?

      existing_items.each do |entry|
        item = entry[:item]
        pub_date_str = item.pub_date.try(&.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT))
        db.exec(
          "UPDATE items SET pub_date = ?, position = ?, comment_url = ?, commentary_url = ? WHERE feed_id = ? AND link = ?",
          pub_date_str,
          entry[:index],
          item.comment_url,
          item.commentary_url,
          feed_id,
          item.link
        )
      end
    end

    def find_with_items(url : String) : FeedData?
      feed_result = db.query_one?(
        "SELECT title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?",
        url
      ) do |row|
        read_feed_row(row)
      end
      return unless feed_result

      feed_id_result = db.query_one?("SELECT id FROM feeds WHERE url = ?", url, as: Int64)
      return unless feed_id_result
      feed_id = feed_id_result

      items = [] of Item
      db.query("SELECT title, link, pub_date, version, comment_url, commentary_url FROM items WHERE feed_id = ? AND (pub_date IS NULL OR pub_date <= datetime('now', '+1 day')) ORDER BY pub_date DESC", feed_id) do |rows|
        rows.each do
          items << read_item(rows)
        end
      end

      feed_result.to_feed_data(items)
    end

    def find_with_items_result(url : String) : FeedDataResult
      result = find_with_items(url)
      return FeedDataResult.failure(RepositoryError::NotFound) unless result
      FeedDataResult.success(result)
    rescue DB::Error
      FeedDataResult.failure(RepositoryError::DatabaseError)
    end

    def find_with_items_slice(url : String, limit : Int32, offset : Int32) : FeedData?
      feed_result = db.query_one?(
        "SELECT title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?",
        url
      ) do |row|
        read_feed_row(row)
      end
      return unless feed_result

      items = [] of Item
      query = "SELECT title, link, pub_date, version, comment_url, commentary_url FROM items WHERE feed_id = (SELECT id FROM feeds WHERE url = ?) AND (pub_date IS NULL OR pub_date <= datetime('now', '+1 day')) ORDER BY pub_date DESC LIMIT ? OFFSET ?"

      db.query(query, url, limit, offset) do |rows|
        rows.each do
          items << read_item(rows)
        end
      end

      fd = feed_result.to_feed_data(items)
      fd.header_theme_colors = feed_result.header_theme_colors if feed_result.header_theme_colors
      fd
    end

    def find_with_items_slice_result(url : String, limit : Int32, offset : Int32) : FeedDataResult
      result = find_with_items_slice(url, limit, offset)
      return FeedDataResult.failure(RepositoryError::NotFound) unless result
      FeedDataResult.success(result)
    rescue DB::Error
      FeedDataResult.failure(RepositoryError::DatabaseError)
    end
  end
end

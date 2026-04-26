require "db"
require "../models"
require "../services/database_service"
require "./repository_base"

module QuickHeadlines::Repositories
  class FeedRepository < RepositoryBase
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
      favicon_data : String?,
      id : Int64? do
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

    private def read_item(rows : DB::ResultSet) : Item
      title = rows.read(String)
      link = rows.read(String)
      pub_date_str = rows.read(String?)
      version = rows.read(String?)
      comment_url = rows.read(String?)
      commentary_url = rows.read(String?)

      pub_date = parse_db_time(pub_date_str)
      Item.new(title, link, pub_date, version, comment_url, commentary_url)
    end

    def find_all_urls : Set(String)
      urls = Set(String).new
      db.query("SELECT url FROM feeds") do |rows|
        rows.each do
          urls << rows.read(String)
        end
      end
      urls
    end

    def find_last_fetched_time(url : String) : Time?
      result = db.query_one?("SELECT last_fetched FROM feeds WHERE url = ?", url, as: String?)
      parse_db_time(result)
    end

    def count_all : Int32
      result = db.query_one?("SELECT COUNT(*) FROM feeds", as: Int64)
      result ? result.to_i : 0
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
      existing = db.query_one?("SELECT header_color, header_text_color, header_theme_colors FROM feeds WHERE id = ?", feed_id) do |row|
        {
          color:      row.read(String?),
          text_color: row.read(String?),
          theme:      row.read(String?),
        }
      end

      header_color_to_save = feed_data.header_color.nil? ? existing.try(&.[:color]) : feed_data.header_color
      header_text_color_to_save = feed_data.header_text_color.nil? ? existing.try(&.[:text_color]) : feed_data.header_text_color
      header_theme_to_save = feed_data.header_theme_colors.nil? ? existing.try(&.[:theme]) : feed_data.header_theme_colors

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

      batch_insert(items, feed_id)
    end

    private def batch_insert(items : Array(Item), feed_id : Int64) : Nil
      items.each_slice(50) do |batch|
        values_clause = batch.map do
          "(?, ?, ?, ?, ?, ?, ?)"
        end.join(", ")
        args = batch.flat_map do |item|
          pub_date_str = item.pub_date.try(&.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT))
          [feed_id, item.title, item.link, pub_date_str, item.version, item.comment_url, item.commentary_url]
        end
        db.exec("INSERT OR IGNORE INTO items (feed_id, title, link, pub_date, version, comment_url, commentary_url) VALUES #{values_clause}", args: args)
      end
    end

    def find_with_items(url : String) : FeedData?
      feed_result = db.query_one?(
        "SELECT id, title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?",
        url
      ) do |row|
        feed_id = row.read(Int64)
        read_feed_row_with_id(row, feed_id)
      end
      return unless feed_result

      items = [] of Item
      db.query("SELECT title, link, pub_date, version, comment_url, commentary_url FROM items WHERE feed_id = ? AND (pub_date IS NULL OR pub_date <= datetime('now', '+1 day')) ORDER BY pub_date DESC LIMIT ?", feed_result.id, QuickHeadlines::Constants::MAX_FEED_ITEMS_LOAD) do |rows|
        rows.each do
          items << read_item(rows)
        end
      end

      feed_result.to_feed_data(items)
    end

    private def read_feed_row_with_id(rows : DB::ResultSet, feed_id : Int64) : FeedRowData
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
        rows.read(String?),
        feed_id
      )
    end
  end
end

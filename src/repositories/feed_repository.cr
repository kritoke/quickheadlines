require "db"

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

    def find_by_pattern(pattern : String) : Quickheadlines::Entities::Feed?
      normalized = pattern.strip.rstrip('/')
        .gsub(/\/rss(\.xml)?$/i, "")
        .gsub(/\/feed(\.xml)?$/i, "")

      find_by_url(normalized) || find_by_url("#{normalized}/") || find_by_url("#{normalized}/rss")
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

    def update_last_fetched(url : String, time : Time = Time.utc) : Void
      @db.exec(
        "UPDATE feeds SET last_fetched = ? WHERE url = ?",
        time.to_s("%Y-%m-%d %H:%M:%S"),
        url
      )
    end

    def update_header_colors(url : String, bg : String?, text : String?) : Void
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

    def delete_by_url(url : String) : Void
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

    def upsert_with_items(feed_data : FeedData) : Void
      @db.exec("BEGIN TRANSACTION")

      begin
        result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", feed_data.url, as: {Int64})

        feed_id : Int64
        if result
          feed_id = result
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
        else
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
          feed_id = @db.scalar("SELECT last_insert_rowid()").as(Int64)
        end

        existing_titles = @db.query_all("SELECT title FROM items WHERE feed_id = ?", feed_id, as: String).to_set

        feed_data.items.each_with_index do |item, index|
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

        @db.exec("COMMIT")
      rescue ex
        STDERR.puts "[FeedRepository ERROR] Failed to upsert feed #{feed_data.title}: #{ex.message}"
        @db.exec("ROLLBACK")
        raise ex
      end
    end
  end
end

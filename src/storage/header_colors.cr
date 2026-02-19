module HeaderColorsRepository
  def update_header_colors(feed_url : String, bg_color : String, text_color : String)
    @mutex.synchronize do
      normalized_url = normalize_feed_url(feed_url)

      existing = @db.query_one?("SELECT header_color, header_text_color FROM feeds WHERE url = ?", normalized_url) do |row|
        {header_color: row.read(String?), header_text_color: row.read(String?)}
      end

      if existing.nil?
        existing = @db.query_one?("SELECT header_color, header_text_color FROM feeds WHERE url = ?", feed_url) do |row|
          {header_color: row.read(String?), header_text_color: row.read(String?)}
        end
      end

      if existing.nil?
        all_urls = @db.query_all("SELECT url FROM feeds LIMIT 10", as: String)
        STDERR.puts "[#{Time.local}] Warning: Feed '#{feed_url}' not found in database. Sample DB URLs: #{all_urls.join(", ")}"
        return
      end

      should_update_bg = existing[:header_color].nil? || existing[:header_color] == ""
      should_update_text = existing[:header_text_color].nil? || existing[:header_text_color] == ""

      if should_update_bg || should_update_text
        updates = [] of String
        values = [] of String

        if should_update_bg
          updates << "header_color = ?"
          values << bg_color
        end

        if should_update_text
          updates << "header_text_color = ?"
          values << text_color
        end

        unless updates.empty?
          query = "UPDATE feeds SET " + updates.join(", ") + " WHERE url = ?"
          values << feed_url
          @db.exec(query, args: values)
          STDERR.puts "[#{Time.local}] Saved extracted header colors for #{feed_url}: bg=#{bg_color}, text=#{text_color}"
        end
      else
        STDERR.puts "[#{Time.local}] Skipped header colors for #{feed_url}: already set"
      end
    end
  end

  def get_header_colors(feed_url : String) : {bg_color: String?, text_color: String?}
    @mutex.synchronize do
      result = @db.query_one?("SELECT header_color, header_text_color FROM feeds WHERE url = ?", feed_url) do |row|
        {bg_color: row.read(String?), text_color: row.read(String?)}
      end
      result || {bg_color: nil, text_color: nil}
    end
  end

  def update_feed_theme_colors(feed_url : String, theme_json : String)
    @mutex.synchronize do
      normalized_url = normalize_feed_url(feed_url)

      existing = @db.query_one?("SELECT id FROM feeds WHERE url = ?", normalized_url, as: {Int64})

      if existing.nil?
        existing = @db.query_one?("SELECT id FROM feeds WHERE url = ?", feed_url, as: {Int64})
      end

      unless existing
        STDERR.puts "[#{Time.local}] Warning: Cannot save header_theme_colors - feed not found: #{feed_url}"
        return
      end

      feed_id = existing
      begin
        @db.exec("UPDATE feeds SET header_theme_colors = ? WHERE id = ?", theme_json, feed_id)
        STDERR.puts "[#{Time.local}] Saved header_theme_colors for #{feed_url}"
      rescue ex
        STDERR.puts "[#{Time.local}] Error saving header_theme_colors for #{feed_url}: #{ex.message}"
      end
    end
  end

  def get_feed_theme_colors(feed_url : String) : String?
    @mutex.synchronize do
      normalized_url = normalize_feed_url(feed_url)
      result = @db.query_one?("SELECT header_theme_colors FROM feeds WHERE url = ?", normalized_url, as: {String?})

      if result.nil?
        result = @db.query_one?("SELECT header_theme_colors FROM feeds WHERE url = ?", feed_url, as: {String?})
      end

      result
    end
  end

  def find_feed_url_by_pattern(url_pattern : String) : String?
    @mutex.synchronize do
      result = @db.query_one?("SELECT url FROM feeds WHERE url = ?", url_pattern, as: {String?})
      return result if result

      normalized = url_pattern.rstrip('/').gsub(/\/rss(\.xml)?$/i, "").gsub(/\/feed(\.xml)?$/i, "")

      result = @db.query_one?("SELECT url FROM feeds WHERE url = ? OR url = ? OR url LIKE ? || '/%'",
        normalized,
        url_pattern,
        normalized) do |row|
        row.read(String?)
      end
      result
    end
  end
end

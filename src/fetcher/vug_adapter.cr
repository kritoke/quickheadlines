require "vug"
require "../favicon_storage"
require "../config"

module VugAdapter
  CACHE = Vug::MemoryCache.new

  def self.config : Vug::Config
    Vug::Config.new(
      timeout: 10.seconds,
      connect_timeout: 5.seconds,
      on_save: ->(url : String, data : Bytes, content_type : String) do
        return if url.nil? || url.starts_with?("placeholder:") || url.includes?("#placeholder")
        FaviconStorage.save_favicon(url, data, content_type)
      end,
      on_load: ->(url : String) do
        return nil if url.nil? || url.starts_with?("placeholder:") || url.includes?("#placeholder")
        FaviconStorage.get_or_fetch(url)
      end,
      on_debug: ->(msg : String) do
        debug_log(msg)
      end,
      on_error: ->(ctx : String, error_msg : String) do
        Log.for("quickheadlines.feed").error { "ERROR in #{ctx}: #{error_msg}" }
      end,
      on_warning: ->(msg : String) do
        Log.for("quickheadlines.feed").warn { "WARNING: #{msg}" }
      end
    )
  end

  private def self.fetch(url : String) : Vug::Result
    Vug.fetch(url, config, CACHE)
  end

  private def self.fetch_for_site(site_url : String) : Vug::Result
    Vug.site(site_url, config, CACHE)
  end

  def self.google_favicon_url(domain : String) : String
    Vug.google_favicon_url(domain)
  end

  def self.clear_cache : Nil
    CACHE.clear
  end

  def self.get_favicon(site_url : String, parsed_favicon : String? = nil, previous_favicon : String? = nil, previous_favicon_data : String? = nil) : {String?, String?}
    if previous_favicon_data && previous_favicon_data.starts_with?("/favicons/")
      favicon_path = FaviconStorage.favicon_dir + previous_favicon_data
      if File.exists?(favicon_path) && !previous_favicon_data.includes?("placeholder")
        return {previous_favicon_data, previous_favicon_data}
      end
    end

    if parsed_favicon && !parsed_favicon.starts_with?("#") && !parsed_favicon.includes?("#") && !parsed_favicon.starts_with?("placeholder:")
      result = fetch(parsed_favicon)
      if result.local_path && (url = result.url)
        return {url, result.local_path}
      end
    end

    if site_url && !site_url.starts_with?("#") && !site_url.includes?("#") && !site_url.starts_with?("placeholder:")
      result = fetch_for_site(site_url)
      if result.local_path && (url = result.url) && !url.starts_with?("placeholder:")
        return {url, result.local_path}
      end
    end

    {nil, nil}
  end
end

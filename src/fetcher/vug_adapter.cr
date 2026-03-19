require "vug"
require "../constants"
require "../favicon_storage"
require "../health_monitor"
require "../config"

module VugAdapter
  CACHE = Vug::MemoryCache.new

  def self.config : Vug::Config
    Vug::Config.new(
      timeout: Constants::HTTP_TIMEOUT_SECONDS.seconds,
      connect_timeout: Constants::HTTP_CONNECT_TIMEOUT.seconds,
      on_save: ->(url : String, data : Bytes, content_type : String) do
        FaviconStorage.save_favicon(url, data, content_type)
      end,
      on_load: ->(url : String) do
        FaviconStorage.get_or_fetch(url)
      end,
      on_debug: ->(msg : String) do
        debug_log(msg)
      end,
      on_error: ->(ctx : String, error_msg : String) do
        HealthMonitor.log_error(ctx, error_msg)
      end,
      on_warning: ->(msg : String) do
        HealthMonitor.log_warning(msg)
      end
    )
  end

  def self.fetch(url : String) : Vug::Result
    Vug.fetch(url, config, CACHE)
  end

  def self.fetch_for_site(site_url : String) : Vug::Result
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
      return {previous_favicon_data, previous_favicon_data}
    end

    if parsed_favicon
      result = fetch(parsed_favicon)
      if result.local_path
        return {result.url, result.local_path}
      end
    end

    result = fetch_for_site(site_url)
    if result.local_path
      return {result.url, result.local_path}
    end

    {nil, nil}
  end
end

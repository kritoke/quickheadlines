require "openssl"
require "file_utils"
require "base64"
require "http/client"
require "./utils"
require "./storage/cache_utils"
require "./infrastructure/actor"

# FaviconActor — manages saving and serving favicons as static files.
#
# All file I/O is serialized through the actor mailbox. This eliminates
# race conditions where concurrent save_favicon calls could write to
# the same file simultaneously (e.g., Google fallback for tiny favicons).
#
class FaviconActor < Actor
  POSSIBLE_EXTENSIONS = {"png", "jpg", "jpeg", "ico", "svg", "webp"}

  # Minimum size threshold for favicons to avoid tiny 16x16 2-color icons.
  FAVICON_MIN_SIZE = 800
  # Absolute minimum - any file smaller than this gets Google fallback
  FAVICON_ABSOLUTE_MIN = 200

  # =========================================================================
  # Messages
  # =========================================================================

  # Call messages (request-reply)
  def_call save_favicon(url : String, image_data : Bytes, content_type : String), String?
  def_call fetch_and_save(url : String), String?

  # Maps URL -> reply channel for in-flight HTTP fetches.
  # Each fetch_and_save gets its own channel, routed by URL.
  private struct HttpFetchResult
    getter url : String
    getter success : Bool
    getter image_data : Bytes?
    getter content_type : String?
    getter error : String?

    def initialize(@url, @success, @image_data, @content_type, @error)
    end
  end

  private def handle_fetch_and_save(url : String) : String?
    reply_ch = Channel(String?).new
    @pending_fetches[url] = reply_ch
    spawn(name: "favicon_http_fetch_#{url.hash}") do
      result = perform_http_fetch(url)
      send_message(HttpFetchResult.new(url, result[:success], result[:image_data], result[:content_type], result[:error]))
    end
    result = reply_ch.receive
    @pending_fetches.delete(url)
    result
  end

  private def perform_http_fetch(url : String) : {success: Bool, image_data: Bytes?, content_type: String?, error: String?}
    uri = URI.parse(url)
    host = uri.host
    return {success: false, image_data: nil, content_type: nil, error: "no host"} unless host
    return {success: false, image_data: nil, content_type: nil, error: "SSRF: private host"} if reject_private_host?(host, url)

    client = HTTP::Client.new(host, port: uri.port, tls: uri.scheme == "https")
    apply_default_timeouts(client)

    redirect_client : HTTP::Client? = nil

    begin
      headers = HTTP::Headers{"User-Agent" => "Mozilla/5.0 (compatible; QuickHeadlines/1.0)"}
      response = client.get(uri.request_target, headers: headers)

      if response.status.redirection?
        redirect_url = response.headers["Location"]?
        if redirect_url
          redirected_uri = uri.resolve(redirect_url)
          redirect_host = redirected_uri.host
          return {success: false, image_data: nil, content_type: nil, error: "SSRF: redirect to private host #{redirect_host}"} if redirect_host && reject_private_host?(redirect_host, redirect_url)
          if redirect_host
            redirect_client = HTTP::Client.new(redirect_host, port: redirected_uri.port, tls: redirected_uri.scheme == "https")
            apply_default_timeouts(redirect_client)
            response = redirect_client.get(redirected_uri.request_target, headers: headers)
          end
        end
      end

      return {success: false, image_data: nil, content_type: nil, error: "HTTP #{response.status.code}"} unless response.status.success?

      content_type = response.content_type || "image/png"
      body = response.body.to_slice
      {success: true, image_data: body, content_type: content_type, error: nil}
    rescue ex
      {success: false, image_data: nil, content_type: nil, error: "fetch error: #{ex.class}"}
    ensure
      redirect_client.try(&.close)
      client.close
    end
  end

  def_call get_or_fetch(url : String), String?

  # Cast messages (fire-and-forget)
  def_cast init_storage

  # =========================================================================
  # Actor state
  # =========================================================================

  @favicon_dir : String
  @initialized : Bool = false
  @pending_fetches : Hash(String, Channel(String?)) = Hash(String, Channel(String?)).new

  def initialize(@name : String = "FaviconActor")
    super(@name, mailbox_size: 100)
    @favicon_dir = compute_favicon_dir
  end

  private def compute_favicon_dir : String
    File.join(get_cache_dir(nil), "favicons")
  end

  # Singleton access
  @@instance : FaviconActor?
  @@instance_mutex = Mutex.new

  def self.instance : FaviconActor
    @@instance_mutex.synchronize do
      @@instance ||= FaviconActor.new.tap(&.start)
    end
  end

  # =========================================================================
  # Pure functions — no state, can be called directly
  # =========================================================================

  def self.favicon_dir : String
    instance.@favicon_dir
  end

  def self.disk_path(db_path : String) : String?
    return unless db_path.starts_with?("/favicons/")
    filename = db_path.lchop("/favicons")
    File.join(favicon_dir, filename)
  end

  def self.favicon_hash_for_url(url : String) : String
    hash_input = url.size > QuickHeadlines::Constants::MAX_FAVICON_HASH ? url[0..QuickHeadlines::Constants::MAX_FAVICON_HASH] : url
    OpenSSL::Digest.new("SHA256").update(hash_input).final.hexstring
  end

  def self.favicon_filename(hash : String, ext : String) : String
    "#{hash[0...QuickHeadlines::Constants::FAVICON_HASH_PREFIX_LENGTH]}.#{ext}"
  end

  def self.valid_image_data?(data : Bytes) : Bool
    return false if data.size < 4
    str_start = String.new(data[0..Math.min(data.size - 1, 100)]).downcase
    if str_start.starts_with?("<?xml") || str_start.starts_with?("<html") || str_start.starts_with?("<!doctype")
      return false unless String.new(data).downcase.includes?("<svg")
    end
    true
  end

  # =========================================================================
  # Dispatch — routes messages to handlers
  # =========================================================================

  def dispatch(message : Message) : Nil
    case message
    when CallSaveFavicon  then message.deliver_reply(handle_save_favicon(message.url, message.image_data, message.content_type))
    when CallFetchAndSave then message.deliver_reply(handle_fetch_and_save(message.url))
    when CallGetOrFetch   then message.deliver_reply(handle_get_or_fetch(message.url))
    when CastInitStorage  then handle_init_storage
    when HttpFetchResult  then handle_http_fetch_result(message)
    else                       raise "Unknown message: #{message.class.name}"
    end
  end

  private def handle_http_fetch_result(result : HttpFetchResult) : Nil
    if ch = @pending_fetches[result.url]?
      begin
        if result.success && (data = result.image_data)
          ct = result.content_type || "image/png"
          saved_path = handle_save_favicon(result.url, data, ct)
          ch.send(saved_path)
        else
          fallback = do_fetch_google_favicon(result.url)
          ch.send(fallback)
        end
      rescue Channel::ClosedError
      ensure
        @pending_fetches.delete(result.url)
      end
    end
  end

  # =========================================================================
  # Handlers — all file I/O happens here, single-threaded
  # =========================================================================

  private def handle_init_storage : Nil
    return if @initialized
    FileUtils.mkdir_p(@favicon_dir) unless Dir.exists?(@favicon_dir)
    @initialized = true
  end

  private def handle_save_favicon(url : String, image_data : Bytes, content_type : String) : String?
    return nil if image_data.size > QuickHeadlines::Constants::FAVICON_MAX_SIZE
    return nil unless FaviconActor.valid_image_data?(image_data)

    hash = FaviconActor.favicon_hash_for_url(url)
    ext = extension_from_content_type(content_type)
    filename = FaviconActor.favicon_filename(hash, ext)
    filepath = File.join(@favicon_dir, filename)
    is_tiny = image_data.size < FAVICON_ABSOLUTE_MIN || (ext == "ico" && image_data.size < FAVICON_MIN_SIZE)

    # Write original favicon
    unless File.exists?(filepath)
      begin
        temp_path = filepath + ".tmp"
        File.write(temp_path, image_data)
        File.rename(temp_path, filepath)
      rescue ex
        Log.for("quickheadlines.storage").error(exception: ex) { "Error saving favicon" }
        File.delete(filepath + ".tmp") if File.exists?(filepath + ".tmp")
        return nil
      end
    end

    # If tiny, try Google fallback (network I/O happens inside actor)
    if is_tiny
      Log.for("quickheadlines.storage").debug { "Tiny favicon (#{image_data.size} bytes) for #{url}, trying Google fallback" }
      if google_saved = do_fetch_google_favicon(url)
        Log.for("quickheadlines.storage").debug { "Google fallback saved: #{google_saved}" }
        File.delete(filepath) if File.exists?(filepath)
        return google_saved
      end
    end

    "/favicons/#{filename}"
  end

  private def handle_fetch_and_save(url : String) : String?
    return nil unless url.starts_with?("http")

    uri = URI.parse(url)
    host = uri.host
    return nil unless host
    return nil if reject_private_host?(host, url)

    client = HTTP::Client.new(host, port: uri.port, tls: uri.scheme == "https")
    apply_default_timeouts(client)

    redirect_client : HTTP::Client? = nil

    begin
      headers = HTTP::Headers{"User-Agent" => "Mozilla/5.0 (compatible; QuickHeadlines/1.0)"}
      response = client.get(uri.request_target, headers: headers)

      if response.status.redirection?
        redirect_url = response.headers["Location"]?
        if redirect_url
          redirected_uri = uri.resolve(redirect_url)
          redirect_host = redirected_uri.host
          # Block SSRF: validate redirect target before following
          if redirect_host && reject_private_host?(redirect_host, redirect_url)
            Log.for("quickheadlines.storage").debug { "SSRF blocked: redirect to #{redirect_host} from #{url}" }
            return nil
          end
          if redirect_host
            redirect_client = HTTP::Client.new(redirect_host, port: redirected_uri.port, tls: redirected_uri.scheme == "https")
            apply_default_timeouts(redirect_client)
            response = redirect_client.get(redirected_uri.request_target, headers: headers)
          else
            return nil
          end
        end
      end

      unless response.status.success?
        Log.for("quickheadlines.storage").debug { "HTTP #{response.status.code} for #{url}" }
        return nil
      end

      content_type = response.content_type || "image/png"
      body = response.body

      # Call handle_save_favicon directly (we're already in the actor fiber)
      handle_save_favicon(url, body.to_slice, content_type)
    rescue ex
      Log.for("quickheadlines.storage").error(exception: ex) { "Failed to fetch #{url}" }
      nil
    ensure
      redirect_client.try(&.close)
      client.close
    end
  end

  private def handle_get_or_fetch(url : String) : String?
    hash = FaviconActor.favicon_hash_for_url(url)

    POSSIBLE_EXTENSIONS.each do |ext|
      filename = FaviconActor.favicon_filename(hash, ext)
      filepath = File.join(@favicon_dir, filename)
      return "/favicons/#{filename}" if File.exists?(filepath)
    end

    nil
  end

  # =========================================================================
  # Private helpers — called from within actor fiber
  # =========================================================================

  private def do_fetch_google_favicon(url : String) : String?
    return nil unless domain = extract_domain_from_url(url)
    google_url = "https://www.google.com/s2/favicons?domain=#{domain}&sz=128"

    uri = URI.parse(google_url)
    host = uri.host
    return nil unless host

    client = HTTP::Client.new(host, port: uri.port, tls: true)
    apply_default_timeouts(client)

    begin
      headers = HTTP::Headers{"User-Agent" => "Mozilla/5.0 (compatible; QuickHeadlines/1.0)"}
      response = client.get(uri.request_target, headers: headers)

      # Follow redirects (Google API returns 301)
      if response.status.redirection?
        redirect_url = response.headers["Location"]?
        if redirect_url
          redirect_uri = uri.resolve(redirect_url)
          redirect_host = redirect_uri.host
          if redirect_host
            client.close
            client = HTTP::Client.new(redirect_host, port: redirect_uri.port, tls: redirect_uri.scheme == "https")
            apply_default_timeouts(client)
            response = client.get(redirect_uri.request_target, headers: headers)
          end
        end
      end

      return nil unless response.status.success?

      image_data = response.body.to_slice
      return nil if image_data.size > QuickHeadlines::Constants::FAVICON_MAX_SIZE
      return nil unless FaviconActor.valid_image_data?(image_data)

      content_type = response.content_type || "image/png"
      ext = extension_from_content_type(content_type)
      # Use original URL's hash so next lookup finds the Google fallback
      hash = FaviconActor.favicon_hash_for_url(url)
      filename = FaviconActor.favicon_filename(hash, ext)
      filepath = File.join(@favicon_dir, filename)

      unless File.exists?(filepath)
        temp_path = filepath + ".tmp"
        File.write(temp_path, image_data)
        File.rename(temp_path, filepath)
      end
      "/favicons/#{filename}"
    rescue ex
      Log.for("quickheadlines.storage").error(exception: ex) { "Failed to fetch Google favicon for #{url}" }
      nil
    ensure
      client.close
    end
  end

  private def extract_domain_from_url(url : String) : String?
    uri = URI.parse(url)
    uri.host
  rescue ex : URI::Error
    Log.for("quickheadlines.storage").debug { "extract_domain_from_url: failed to parse '#{url}': #{ex.message}" }
    nil
  end

  private def extension_from_content_type(content_type : String) : String
    case content_type.downcase
    when "image/png"                then "png"
    when "image/jpeg"               then "jpg"
    when "image/jpg"                then "jpg"
    when "image/x-icon"             then "ico"
    when "image/vnd.microsoft.icon" then "ico"
    when "image/svg+xml"            then "svg"
    when "image/webp"               then "webp"
    else                                 "png"
    end
  end

  private def apply_default_timeouts(client : HTTP::Client) : Nil
    client.read_timeout = QuickHeadlines::Constants::HTTP_READ_TIMEOUT.seconds
    client.write_timeout = QuickHeadlines::Constants::HTTP_WRITE_TIMEOUT.seconds
    client.connect_timeout = QuickHeadlines::Constants::HTTP_CONNECT_TIMEOUT.seconds
  end

  private def reject_private_host?(host : String, url : String) : Bool
    if Utils.private_host?(host)
      Log.for("quickheadlines.storage").debug { "SSRF blocked: private host #{host} in #{url}" }
      return true
    end
    false
  end
end

# Backward-compatible module API — delegates to FaviconActor
module FaviconStorage
  POSSIBLE_EXTENSIONS = FaviconActor::POSSIBLE_EXTENSIONS

  def self.favicon_dir : String
    FaviconActor.favicon_dir
  end

  def self.disk_path(db_path : String) : String?
    FaviconActor.disk_path(db_path)
  end

  def self.favicon_hash_for_url(url : String) : String
    FaviconActor.favicon_hash_for_url(url)
  end

  def self.favicon_filename(hash : String, ext : String) : String
    FaviconActor.favicon_filename(hash, ext)
  end

  def self.valid_image_data?(data : Bytes) : Bool
    FaviconActor.valid_image_data?(data)
  end

  def self.init : Nil
    FaviconActor.instance.init_storage
  end

  def self.save_favicon(url : String, image_data : Bytes, content_type : String) : String?
    FaviconActor.instance.save_favicon(url, image_data, content_type)
  end

  def self.fetch_and_save(url : String) : String?
    FaviconActor.instance.fetch_and_save(url)
  end

  def self.get_or_fetch(url : String) : String?
    FaviconActor.instance.get_or_fetch(url)
  end
end

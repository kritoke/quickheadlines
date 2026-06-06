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

  def_call get_or_fetch(url : String), String?

  # Cast messages (fire-and-forget)
  def_cast init_storage

  # =========================================================================
  # Actor state
  # =========================================================================

  @favicon_dir : String
  @initialized : Bool = false
  @client_pool : Hash(String, HTTP::Client) = {} of String => HTTP::Client

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

    case data[0]
    when 0x89
      data.size >= 8 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 && data[4] == 0x0D && data[5] == 0x0A && data[6] == 0x1A && data[7] == 0x0A
    when 0xFF
      data.size >= 3 && data[1] == 0xD8 && data[2] == 0xFF
    when 0x00
      (data.size >= 4 && data[1] == 0x00 && data[2] == 0x01 && data[3] == 0x00) ||
        (data.size >= 4 && data[1] == 0x00 && data[2] == 0x02 && data[3] == 0x00)
    when 0x52
      data.size >= 12 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 && data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50
    else
      str_start.includes?("<svg")
    end
  end

  # =========================================================================
  # Dispatch — routes messages to handlers
  # =========================================================================

  def dispatch(message : Message) : Nil
    case message
    when CallSaveFavicon  then message.deliver_reply_json(handle_save_favicon(message.url, message.image_data, message.content_type).to_json)
    when CallFetchAndSave then message.deliver_reply_json(handle_fetch_and_save(message.url).to_json)
    when CallGetOrFetch   then message.deliver_reply_json(handle_get_or_fetch(message.url).to_json)
    when CastInitStorage  then handle_init_storage
    else                       raise "Unknown message: #{message.class.name}"
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
    response = fetch_http(uri)
    return nil unless response

    content_type = response.content_type || "image/png"
    handle_save_favicon(url, response.body.to_slice, content_type)
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

  FETCH_HEADERS = HTTP::Headers{"User-Agent" => "Mozilla/5.0 (compatible; QuickHeadlines/1.0)"}

  private def fetch_http(uri : URI, check_ssrf : Bool = true) : HTTP::Client::Response?
    host = uri.host
    return nil unless host
    return nil if check_ssrf && reject_private_host?(host, uri.to_s)

    pool_key = "#{host}:#{uri.port}:#{uri.scheme == "https"}"
    client = pooled_client(host, uri.port, uri.scheme == "https")

    begin
      response = client.get(uri.request_target, headers: FETCH_HEADERS)

      if response.status.redirection?
        redirect_url = response.headers["Location"]?
        if redirect_url
          redirect_uri = uri.resolve(redirect_url)
          redirect_host = redirect_uri.host
          if redirect_host && reject_private_host?(redirect_host, redirect_url)
            Log.for("quickheadlines.storage").debug { "SSRF blocked: redirect to #{redirect_host}" }
            return nil
          end
          if redirect_host
            client = pooled_client(redirect_host, redirect_uri.port, redirect_uri.scheme == "https")
            response = client.get(redirect_uri.request_target, headers: FETCH_HEADERS)
          else
            return nil
          end
        end
      end

      response.status.success? ? response : nil
    rescue ex
      @client_pool.delete(pool_key)
      client.close rescue nil
      Log.for("quickheadlines.storage").error(exception: ex) { "HTTP fetch failed for #{uri.host}" }
      nil
    end
  end

  private def do_fetch_google_favicon(url : String) : String?
    return nil unless domain = extract_domain_from_url(url)
    google_url = "https://www.google.com/s2/favicons?domain=#{domain}&sz=128"

    uri = URI.parse(google_url)
    response = fetch_http(uri, check_ssrf: false)
    return nil unless response

    image_data = response.body.to_slice
    return nil if image_data.size > QuickHeadlines::Constants::FAVICON_MAX_SIZE
    return nil unless FaviconActor.valid_image_data?(image_data)

    content_type = response.content_type || "image/png"
    ext = extension_from_content_type(content_type)
    hash = FaviconActor.favicon_hash_for_url(url)
    filename = FaviconActor.favicon_filename(hash, ext)
    filepath = File.join(@favicon_dir, filename)

    unless File.exists?(filepath)
      temp_path = filepath + ".tmp"
      File.write(temp_path, image_data)
      File.rename(temp_path, filepath)
    end
    "/favicons/#{filename}"
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

  # Get or create a pooled HTTP client for the given host.
  # Reuses existing connections to avoid TCP/TLS handshake overhead.
  private def pooled_client(host : String, port : Int32?, tls : Bool) : HTTP::Client
    pool_key = "#{host}:#{port}:#{tls}"
    if client = @client_pool[pool_key]?
      return client
    end
    client = HTTP::Client.new(host, port: port, tls: tls)
    apply_default_timeouts(client)
    @client_pool[pool_key] = client
    client
  end

  # Close idle pooled clients (called during cleanup).
  def close_pooled_clients : Nil
    @client_pool.each_value do |client|
      client.close rescue nil
    end
    @client_pool.clear
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

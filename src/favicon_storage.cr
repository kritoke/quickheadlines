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

  # Absolute minimum size for any favicon. Files smaller than this are
  # almost certainly broken/empty responses (a valid ICO header is at
  # least 22 bytes, a valid PNG signature is 8 bytes, etc.). Below this
  # threshold we still fall back to Google.
  FAVICON_ABSOLUTE_MIN = 100

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

  MAX_CLIENT_POOL_SIZE = 32

  @favicon_dir : String
  @initialized : Bool = false
  @client_pool : Hash(String, HTTP::Client) = {} of String => HTTP::Client
  @client_pool_order : Array(String) = [] of String

  def initialize(@name : String = "FaviconActor")
    super(@name, mailbox_size: 100)
    @favicon_dir = compute_favicon_dir
  end

  private def compute_favicon_dir : String
    File.join(QuickHeadlines::CacheUtils.get_cache_dir(nil), "favicons")
  end

  # Class-level accessor — instance must be created and wired by AppBootstrap.
  @@instance : FaviconActor?

  def self.instance : FaviconActor
    @@instance || raise "FaviconActor not initialized. AppBootstrap must create and set FaviconActor.instance=."
  end

  def self.instance? : FaviconActor?
    @@instance
  end

  def self.instance=(value : FaviconActor)
    @@instance = value
  end

  def self.reset : Nil
    if inst = @@instance
      inst.shutdown rescue nil
    end
    @@instance = nil
  end

  # HTTP client pool size for diagnostics
  def client_pool_size : Int32
    @client_pool.size
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

  # Parse ICO header to extract frame count and the largest dimension.
  # Returns nil if the data isn't a valid ICO file. Used to validate that
  # a real .ico favicon (e.g. 318-byte single-frame 16x16) shouldn't be
  # treated as a "tiny placeholder" by the Google fallback heuristic.
  #
  # ICO header layout (per Microsoft spec):
  #   bytes 0-1: reserved (0x0000)
  #   bytes 2-3: type (0x0001 for icon, 0x0002 for cursor)
  #   bytes 4-5: number of images (little-endian)
  #   bytes 6+:  16-byte directory entries, each with width (byte 6),
  #              height (byte 7) at the start
  def self.parse_ico_info(data : Bytes) : {Int32, Int32}?
    return if data.size < 6
    return unless data[0] == 0x00 && data[1] == 0x00
    return unless (data[2] == 0x01 || data[2] == 0x02) && data[3] == 0x00

    frame_count = data[4].to_i + (data[5].to_i << 8)
    return if frame_count == 0

    # Header is 6 bytes + 16 bytes per directory entry. Need at least
    # the first entry's directory to validate.
    return if data.size < 6 + 16

    largest_dim = 0
    frame_count.times do |i|
      entry_offset = 6 + (i * 16)
      break if entry_offset + 2 > data.size
      # Width/height are 0x00 in the entry → 256 in the icon
      w_raw = data[entry_offset].to_i
      h_raw = data[entry_offset + 1].to_i
      w = w_raw == 0 ? 256 : w_raw
      h = h_raw == 0 ? 256 : h_raw
      max_dim = {w, h}.max
      largest_dim = max_dim if max_dim > largest_dim
    end

    {frame_count, largest_dim}
  end

  # Determine whether a freshly-saved favicon warrants a Google fallback
  # attempt. Replaces the old size-based heuristic that mis-classified
  # real 16x16 single-frame ICOs (typically 318-1500 bytes) as "tiny".
  #
  # A favicon is treated as broken/tiny only when:
  #   - it is smaller than FAVICON_ABSOLUTE_MIN bytes (broken/empty response)
  #   - OR it's an ICO with an invalid header / zero frames (corrupt)
  # Real 16x16 single-frame ICOs are valid even at ~318 bytes, so we no
  # longer trigger Google fallback for them.
  def self.needs_fallback?(image_data : Bytes, ext : String) : Bool
    return true if image_data.size < FAVICON_ABSOLUTE_MIN

    if ext == "ico"
      info = parse_ico_info(image_data)
      return true if info.nil? || info[0] == 0
    end

    false
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

  private def write_atomically(filepath : String, data : Bytes) : Bool
    return true if File.exists?(filepath)
    temp_path = "#{filepath}.tmp"
    begin
      File.write(temp_path, data)
      File.rename(temp_path, filepath)
      true
    rescue ex
      Log.for("quickheadlines.storage").error(exception: ex) { "Error writing file atomically: #{filepath}" }
      begin
        File.delete(temp_path)
      rescue
      end
      false
    end
  end

  private def handle_save_favicon(url : String, image_data : Bytes, content_type : String) : String?
    return if image_data.size > QuickHeadlines::Constants::FAVICON_MAX_SIZE
    return unless FaviconActor.valid_image_data?(image_data)

    hash = FaviconActor.favicon_hash_for_url(url)
    ext = extension_from_content_type(content_type)
    filename = FaviconActor.favicon_filename(hash, ext)
    filepath = File.join(@favicon_dir, filename)
    needs_fallback = FaviconActor.needs_fallback?(image_data, ext)

    # Write original favicon
    unless write_atomically(filepath, image_data)
      return
    end

    # Only attempt Google fallback when the original is genuinely broken.
    # When the fallback succeeds, only swap to its result if it's strictly
    # larger than the original — never delete a real favicon in favor of
    # a smaller one (which is what produces the "gray block" symptom when
    # Google's stub-PNG replaces a valid 16x16 ICO).
    if needs_fallback
      Log.for("quickheadlines.storage").debug { "Tiny favicon (#{image_data.size} bytes) for #{url}, trying Google fallback" }
      if google_saved = do_fetch_google_favicon(url, image_data.size)
        Log.for("quickheadlines.storage").debug { "Google fallback saved: #{google_saved}" }
        # do_fetch_google_favicon has already validated that the
        # replacement is strictly better than the original.
        File.delete(filepath) if File.exists?(filepath)
        return google_saved
      end
    end

    "/favicons/#{filename}"
  end

  private def handle_fetch_and_save(url : String) : String?
    return unless url.starts_with?("http")

    uri = URI.parse(url)
    response = fetch_http(uri)
    return unless response

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
    return unless host
    return if check_ssrf && reject_private_host?(host, uri.to_s)

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
            return
          end
          if redirect_host
            client = pooled_client(redirect_host, redirect_uri.port, redirect_uri.scheme == "https")
            response = client.get(redirect_uri.request_target, headers: FETCH_HEADERS)
          else
            return
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

  private def do_fetch_google_favicon(url : String, original_size : Int32 = 0) : String?
    return unless domain = extract_domain_from_url(url)
    google_url = "https://www.google.com/s2/favicons?domain=#{domain}&sz=128"

    uri = URI.parse(google_url)
    response = fetch_http(uri, check_ssrf: false)
    return unless response

    image_data = response.body.to_slice
    return if image_data.size > QuickHeadlines::Constants::FAVICON_MAX_SIZE
    return unless FaviconActor.valid_image_data?(image_data)

    # Don't replace a real favicon with a smaller or equal-sized response.
    # Google's s2/favicons often returns a small stub PNG (~100-300 bytes)
    # when no real icon is available. Swapping to a smaller file is what
    # produces the "gray block" symptom for sites with valid small ICOs.
    if original_size > 0 && image_data.size <= original_size
      Log.for("quickheadlines.storage").debug { "Google fallback (#{image_data.size}B) not better than original (#{original_size}B), keeping original" }
      return
    end

    content_type = response.content_type || "image/png"
    ext = extension_from_content_type(content_type)
    hash = FaviconActor.favicon_hash_for_url(url)
    filename = FaviconActor.favicon_filename(hash, ext)
    filepath = File.join(@favicon_dir, filename)

    write_atomically(filepath, image_data) ? "/favicons/#{filename}" : nil
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
  # LRU eviction when pool exceeds MAX_CLIENT_POOL_SIZE.
  private def pooled_client(host : String, port : Int32?, tls : Bool) : HTTP::Client
    pool_key = "#{host}:#{port}:#{tls}"
    if client = @client_pool[pool_key]?
      # Move to end of access order (most recently used)
      @client_pool_order.delete(pool_key)
      @client_pool_order.push(pool_key)
      return client
    end

    # Evict oldest if at capacity
    evict_oldest_client if @client_pool.size >= MAX_CLIENT_POOL_SIZE

    client = HTTP::Client.new(host, port: port, tls: tls)
    apply_default_timeouts(client)
    @client_pool[pool_key] = client
    @client_pool_order.push(pool_key)
    client
  end

  # Evict the least-recently-used client from the pool.
  private def evict_oldest_client : Nil
    return if @client_pool_order.empty?
    oldest_key = @client_pool_order.shift
    if client = @client_pool.delete(oldest_key)
      client.close rescue nil
      Log.for("quickheadlines.storage").debug { "Evicted HTTP client: #{oldest_key}" }
    end
  end

  # Close idle pooled clients (called during cleanup).
  def close_pooled_clients : Nil
    @client_pool.each_value do |client|
      client.close rescue nil
    end
    @client_pool.clear
    @client_pool_order.clear
  end

  private def reject_private_host?(host : String, url : String) : Bool
    if Utils.private_host?(host)
      Log.for("quickheadlines.storage").debug { "SSRF blocked: private host #{host} in #{url}" }
      return true
    end
    false
  end
end

require "openssl"
require "file_utils"
require "base64"
require "http/client"
require "./utils"
require "./storage/cache_utils"

# FaviconStorage manages saving and serving favicons as static files
# instead of embedding them as base64 data URIs in HTML.
#
# IMPORTANT: Mutex scope is minimized to prevent GC-triggered deadlocks.
# All heavy allocations (OpenSSL hashing, string interpolation) happen
# OUTSIDE the mutex. Only the atomic file check-and-write is protected.
# This avoids Boehm GC mutex initialization conflicts on FreeBSD.
module FaviconStorage
  POSSIBLE_EXTENSIONS = {"png", "jpg", "jpeg", "ico", "svg", "webp"}

  @@mutex = Mutex.new(:unchecked)
  @@favicon_dir : String? = nil
  @@initialized = false

  def self.favicon_dir : String
    @@favicon_dir ||= compute_favicon_dir
    @@favicon_dir.as(String)
  end

  def self.compute_favicon_dir : String
    File.join(get_cache_dir(nil), "favicons")
  end

  def self.init : Nil
    return if @@initialized
    dir = favicon_dir
    FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
    @@initialized = true
  end

  private def self.favicon_hash_for_url(url : String) : String
    hash_input = begin
      url[0..255]
    rescue IndexError
      url
    end
    OpenSSL::Digest.new("SHA256").update(hash_input).final.hexstring
  end

  def self.favicon_hash_for_url_full(url : String) : String
    OpenSSL::Digest.new("SHA256").update(url).final.hexstring
  end

  def self.save_favicon(url : String, image_data : Bytes, content_type : String) : String?
    return if image_data.size > QuickHeadlines::Constants::FAVICON_MAX_SIZE
    return unless valid_image_data?(image_data)

    hash = favicon_hash_for_url(url)
    ext = extension_from_content_type(content_type)
    filename = "#{hash[0...QuickHeadlines::Constants::FAVICON_HASH_PREFIX_LENGTH]}.#{ext}"
    filepath = File.join(favicon_dir, filename)

    @@mutex.synchronize do
      unless File.exists?(filepath)
        begin
          File.write(filepath, image_data)
        rescue ex
          Log.for("quickheadlines.storage").error(exception: ex) { "Error saving favicon" }
          return
        end
      end
    end

    "/favicons/#{filename}"
  end

  def self.valid_image_data?(data : Bytes) : Bool
    return false if data.size < 4
    str_start = String.new(data[0..Math.min(data.size - 1, 100)]).downcase
    if str_start.starts_with?("<?xml") || str_start.starts_with?("<html") || str_start.starts_with?("<!doctype")
      return false unless String.new(data).downcase.includes?("<svg")
    end
    true
  end

  def self.fetch_and_save(url : String) : String?
    return unless url.starts_with?("http")

    uri = URI.parse(url)
    host = uri.host
    return unless host
    if Utils.private_host?(host)
      Log.for("quickheadlines.storage").debug { "SSRF blocked: private host #{host} in #{url}" }
      return
    end

    client = HTTP::Client.new(host, port: uri.port, tls: uri.scheme == "https")
    client.read_timeout = QuickHeadlines::Constants::HTTP_READ_TIMEOUT.seconds
    client.write_timeout = QuickHeadlines::Constants::HTTP_WRITE_TIMEOUT.seconds
    client.connect_timeout = QuickHeadlines::Constants::HTTP_CONNECT_TIMEOUT.seconds

    redirect_client : HTTP::Client? = nil

    begin
      headers = HTTP::Headers{
        "User-Agent" => "Mozilla/5.0 (compatible; QuickHeadlines/1.0)",
      }

      response = client.get(uri.request_target, headers: headers)
      if response.status.redirection?
        redirect_url = response.headers["Location"]?
        if redirect_url
          redirected_uri = uri.resolve(redirect_url)
          redirect_host = redirected_uri.host
          if redirect_host
            if Utils.private_host?(redirect_host)
              Log.for("quickheadlines.storage").debug { "SSRF blocked: private redirect host #{redirect_host} in #{url}" }
              return
            end
            redirect_client = HTTP::Client.new(redirect_host, port: redirected_uri.port, tls: redirected_uri.scheme == "https")
            redirect_client.read_timeout = QuickHeadlines::Constants::HTTP_READ_TIMEOUT.seconds
            redirect_client.write_timeout = QuickHeadlines::Constants::HTTP_WRITE_TIMEOUT.seconds
            redirect_client.connect_timeout = QuickHeadlines::Constants::HTTP_CONNECT_TIMEOUT.seconds
            response = redirect_client.get(redirected_uri.request_target, headers: headers)
          end
        end
      end
      unless response.status.success?
        Log.for("quickheadlines.storage").debug { "HTTP #{response.status.code} for #{url}" }
        return
      end

      content_type = response.content_type || "image/png"
      body = response.body

      save_favicon(url, body.to_slice, content_type)
    rescue ex
      Log.for("quickheadlines.storage").error(exception: ex) { "Failed to fetch #{url}" }
      nil
    ensure
      redirect_client.try(&.close)
      client.close
    end
  end

  def self.get_or_fetch(url : String) : String?
    hash = favicon_hash_for_url_full(url)
    dir = favicon_dir

    @@mutex.synchronize do
      POSSIBLE_EXTENSIONS.each do |ext|
        filepath = File.join(dir, "#{hash[0...QuickHeadlines::Constants::FAVICON_HASH_PREFIX_LENGTH]}.#{ext}")
        return "/favicons/#{hash[0...QuickHeadlines::Constants::FAVICON_HASH_PREFIX_LENGTH]}.#{ext}" if File.exists?(filepath)
      end
    end

    nil
  end

  private def self.extension_from_content_type(content_type : String) : String
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
end

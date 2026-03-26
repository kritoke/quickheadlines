require "openssl"
require "file_utils"
require "base64"

# FaviconStorage manages saving and serving favicons as static files
# instead of embedding them as base64 data URIs in HTML.
module FaviconStorage
  MAX_SIZE = 100 * 1024 # 100KB limit per favicon

  @@mutex = Mutex.new
  @@favicon_dir : String? = nil
  @@initialized = false

  def self.favicon_dir : String
    @@favicon_dir ||= compute_favicon_dir
    @@favicon_dir.as(String)
  end

  def self.compute_favicon_dir : String
    if env = ENV["QUICKHEADLINES_CACHE_DIR"]?
      return File.join(env, "favicons")
    end

    if Dir.exists?("/var/cache")
      begin
        test_dir = "/var/cache/quickheadlines_test_#{Process.pid}"
        Dir.mkdir_p(test_dir)
        File.delete(test_dir)
        return "/var/cache/quickheadlines/favicons"
      rescue
      end
    end

    if xdg = ENV["XDG_CACHE_HOME"]?
      return File.join(xdg, "quickheadlines", "favicons")
    end

    if home = ENV["HOME"]?
      if home.includes?("/Users/") && Dir.exists?(File.join(home, "Library", "Caches"))
        return File.join(home, "Library", "Caches", "quickheadlines", "favicons")
      end
      return File.join(home, ".cache", "quickheadlines", "favicons")
    end

    File.join(Dir.current, "cache", "favicons")
  end

  def self.init : Nil
    @@mutex.synchronize do
      return if @@initialized
      dir = favicon_dir
      FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
      migrate_old_favicons if Dir.exists?("public/favicons")
      @@initialized = true
    end
  end

  def self.migrate_old_favicons : Nil
    old_dir = "public/favicons"
    return unless Dir.exists?(old_dir)
    return unless Dir.exists?(favicon_dir)

    Dir.each_child(old_dir) do |filename|
      old_path = File.join(old_dir, filename)
      new_path = File.join(favicon_dir, filename)
      unless File.exists?(new_path)
        FileUtils.mv(old_path, new_path)
        STDERR.puts "[#{Time.local}] Migrated favicon: #{filename}"
      end
    end
  end

  def self.ensure_initialized : Nil
    init
  end

  # Save favicon data to disk and return the URL path
  # Returns nil if the favicon is too large or saving fails
  def self.save_favicon(url : String, image_data : Bytes, content_type : String) : String?
    return if image_data.size > MAX_SIZE

    # Generate a hash-based filename from the URL (or fetch source) so different
    # fetch paths that point to the same content still produce the same file.
    hash_input = begin
      # If the url is actually a data URI, use its prefix
      url[0..255]
    rescue
      url
    end
    hash = OpenSSL::Digest.new("SHA256").update(hash_input).final.hexstring
    filename = "#{hash[0...16]}.#{extension_from_content_type(content_type)}"
    filepath = File.join(favicon_dir, filename)

    @@mutex.synchronize do
      ensure_initialized
      unless File.exists?(filepath)
        begin
          File.write(filepath, image_data)
        rescue ex
          STDERR.puts "Error saving favicon: #{ex.message}"
          return
        end
      end
    end

    # Return the URL path
    "/favicons/#{filename}"
  end

  # Get favicon URL from cache or fetch and save it
  def self.get_or_fetch(url : String) : String?
    # Check if we already have this favicon saved
    hash = OpenSSL::Digest.new("SHA256").update(url).final.hexstring

    @@mutex.synchronize do
      ensure_initialized
      possible_extensions.each do |ext|
        filename = "#{hash[0...16]}.#{ext}"
        filepath = File.join(favicon_dir, filename)
        if File.exists?(filepath)
          return "/favicons/#{filename}"
        end
      end
    end

    nil
  end

  # Convert a base64 data URI to a saved file URL
  # Returns the URL if successful, nil if the data URI is invalid
  # Uses URL hash for consistency with save_favicon() - same favicon gets same filename
  # regardless of how it was fetched (URL vs data URI)
  def self.convert_data_uri(data_uri : String, url : String) : String?
    return unless data_uri.starts_with?("data:image/")

    # Parse data URI: data:image/png;base64,iVBORw0KGgo...
    match = data_uri.match(/^data:image\/([a-z]+);base64,(.+)$/i)
    return unless match

    content_type = "image/#{match[1]}"
    base64_data = match[2]

    begin
      image_data = Base64.decode(base64_data)
      # Use URL hash for consistency (same URL = same filename)
      hash = OpenSSL::Digest.new("SHA256").update(url).final.hexstring
      filename = "#{hash[0...16]}.#{extension_from_content_type(content_type)}"
      filepath = File.join(favicon_dir, filename)

      @@mutex.synchronize do
        ensure_initialized
        unless File.exists?(filepath)
          File.write(filepath, image_data)
        end
      end

      "/favicons/#{filename}"
    rescue ex
      STDERR.puts "Error converting data URI: #{ex.message}"
      nil
    end
  end

  # Clear all cached favicons
  def self.clear : Nil
    @@mutex.synchronize do
      if Dir.exists?(favicon_dir)
        FileUtils.rm_rf(favicon_dir)
        FileUtils.mkdir_p(favicon_dir)
      end
    end
  end

  # Check if a cached favicon file exists on disk
  # Returns true if any extension of the favicon exists
  def self.exists?(url : String) : Bool
    hash = OpenSSL::Digest.new("SHA256").update(url).final.hexstring

    @@mutex.synchronize do
      possible_extensions.each do |ext|
        filename = "#{hash[0...16]}.#{ext}"
        filepath = File.join(favicon_dir, filename)
        return true if File.exists?(filepath)
      end
    end
    false
  end

  private def self.possible_extensions : Array(String)
    ["png", "jpg", "jpeg", "ico", "svg", "webp"]
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
    else                                 "png" # Default to PNG
    end
  end
end

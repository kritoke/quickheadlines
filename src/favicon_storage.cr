require "openssl"
require "file_utils"
require "base64"

# FaviconStorage manages saving and serving favicons as static files
# instead of embedding them as base64 data URIs in HTML.
module FaviconStorage
  FAVICON_DIR = "public/favicons"
  MAX_SIZE    = 100 * 1024 # 100KB limit per favicon

  @@mutex = Mutex.new

  # Initialize the favicon storage directory
  def self.init : Nil
    @@mutex.synchronize do
      FileUtils.mkdir_p(FAVICON_DIR) unless Dir.exists?(FAVICON_DIR)
    end
  end

  # Save favicon data to disk and return the URL path
  # Returns nil if the favicon is too large or saving fails
  def self.save_favicon(url : String, image_data : Bytes, content_type : String) : String?
    return if image_data.size > MAX_SIZE

    # Generate a hash-based filename from the URL
    hash = OpenSSL::Digest.new("SHA256").update(url).final.hexstring
    filename = "#{hash[0...16]}.#{extension_from_content_type(content_type)}"
    filepath = File.join(FAVICON_DIR, filename)

    @@mutex.synchronize do
      # Only write if file doesn't exist (avoid redundant writes)
      unless File.exists?(filepath)
        begin
          File.write(filepath, image_data)
        rescue ex
          puts "Error saving favicon: #{ex.message}"
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
      possible_extensions.each do |ext|
        filename = "#{hash[0...16]}.#{ext}"
        filepath = File.join(FAVICON_DIR, filename)
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
      filepath = File.join(FAVICON_DIR, filename)

      @@mutex.synchronize do
        unless File.exists?(filepath)
          File.write(filepath, image_data)
        end
      end

      "/favicons/#{filename}"
    rescue ex
      puts "Error converting data URI: #{ex.message}"
      nil
    end
  end

  # Clear all cached favicons
  def self.clear : Nil
    @@mutex.synchronize do
      if Dir.exists?(FAVICON_DIR)
        FileUtils.rm_rf(FAVICON_DIR)
        FileUtils.mkdir_p(FAVICON_DIR)
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
        filepath = File.join(FAVICON_DIR, filename)
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

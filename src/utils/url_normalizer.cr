require "uri"
require "regex"

module QuickHeadlines::Utils
  # URL normalization utilities for deduplication
  # Strips query parameters, fragments, and normalizes trailing slashes
  module UrlNormalizer
    # Common UTM and tracking parameters to strip
    TRACKING_PARAMS = {
      # UTM parameters
      "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
      "utm_reader", "utm_viz_id", "utm_pubreferrer", "utm_swu",
      # Common tracking
      "fbclid", "gclid", "gclsrc", "dclid", "msclkid",
      "mc_cid", "mc_eid",
      "_ga", "_gl",
      "ref", "referrer", "referer",
      "source", "via", "campaign",
      # Social
      "igshid", "twclid", "li_fat_id",
      # Affiliate
      "affiliate", "partner",
      # Click tracking
      "clickid", "sessionid",
      # Other common tracking
      "mkt_tok", "trk", "trkInfo",
      # Reddit
      "context", "depth", "embed",
      # Hacker News
      "focusedCommentId", "commentInformTab",
      # StackOverflow
      "answertab", "votes", "pagesize", "sort",
      # Google
      "sa", "ved", "ei", "usg",
      # News
      "outputType", "pageType", "pf",
    }
    TRACKING_PARAMS_SET = TRACKING_PARAMS.to_set

    # Regex to match tracking parameters
    TRACKING_REGEX = Regex.new(
      "(#{TRACKING_PARAMS.join("|")})=[^&#]*",
      Regex::Options::IGNORE_CASE
    )

    # Normalize a URL for database uniqueness comparison
    # Strips:
    # - Query parameters (except those needed for functionality)
    # - Fragments
    # - Normalizes trailing slashes
    # - Lowercases scheme and host
    def self.normalize(url : String) : String
      return "" if url.empty?

      begin
        uri = URI.parse(url)

        # Handle relative URLs
        return url.strip if uri.scheme.nil? || uri.host.nil?

        # Normalize scheme to lowercase
        scheme = (uri.scheme || "").downcase

        # Normalize host to lowercase
        host = (uri.host || "").downcase

        # Preserve port if non-standard
        port = ""
        if uri.port && uri.port != 80 && uri.port != 443
          port = ":#{uri.port}"
        end

        # Build normalized path
        path = uri.path || "/"
        # Remove trailing slashes unless it's the root path
        path = path.chomp("/") if path != "/" && path.ends_with?("/")
        # Ensure root path is just "/"
        path = "/" if path.empty?

        # Normalize query string - remove tracking params
        query = ""
        if (q = uri.query) && !q.empty?
          query = normalize_query(q)
        end

        # Build final URL
        normalized = "#{scheme}://#{host}#{port}#{path}"
        normalized += "?#{query}" unless query.empty?
        # Don't preserve fragment - it's client-side only

        normalized
      rescue URI::Error
        # If parsing fails, return stripped version
        url.strip
      end
    end

    # Normalize query string by removing tracking parameters
    private def self.normalize_query(query : String) : String
      return "" if query.empty?

      # First, remove tracking parameters (regex is already case-insensitive)
      cleaned = query.gsub(TRACKING_REGEX, "")
      # Also remove tracking params with empty values
      tracking_pattern = Regex.new("#{TRACKING_PARAMS.join("|")}=?(&|$)", Regex::Options::IGNORE_CASE)
      cleaned = cleaned.gsub(tracking_pattern, "")

      # Parse remaining params and keep only functional ones
      params = HTTP::Params.parse(cleaned)

      # Filter out empty values and re-encode
      filtered = HTTP::Params.new
      params.each do |key, value|
        next if key.empty? || value.empty?
        filtered.add(key, value)
      end

      filtered.to_s
    end

    # Extract just the host/domain from a URL
    def self.extract_domain(url : String) : String
      begin
        uri = URI.parse(url)
        uri.host.try(&.downcase) || ""
      rescue URI::Error
        ""
      end
    end

    # Check if two URLs are the same after normalization
    def self.same?(url1 : String, url2 : String) : Bool
      return true if url1 == url2
      normalize(url1) == normalize(url2)
    end
  end
end

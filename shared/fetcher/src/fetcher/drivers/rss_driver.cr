require "xml"
require "html"
require "../driver"

module Fetcher
  class RSSDriver < Driver
    MAX_FEED_SIZE = 5 * 1024 * 1024

    def pull(url : String, headers : HTTP::Headers, etag : String?, last_modified : String?) : Result
      uri = URI.parse(url)
      client = HTTP::Client.new(uri)
      client.connect_timeout = 10.seconds
      client.read_timeout = 30.seconds

      response = client.get(uri.request_target, headers: headers)

      case response.status_code
      when 304
        Result.new(
          entries: [] of Entry,
          etag: response.headers["ETag"]?,
          last_modified: response.headers["Last-Modified"]?,
          site_link: nil,
          favicon: nil,
          error_message: nil
        )
      when 200..299
        parse_feed(response.body_io, url)
      else
        build_error_result("HTTP #{response.status_code}")
      end
    rescue ex : IO::TimeoutError
      build_error_result("Timeout")
    rescue ex
      build_error_result(ex.message || "Unknown error")
    end

    private def parse_feed(io : IO, url : String) : Result
      buffer = IO::Memory.new
      bytes_copied = IO.copy(io, buffer, limit: MAX_FEED_SIZE)

      if bytes_copied >= MAX_FEED_SIZE
        return build_error_result("Feed too large (>5MB)")
      end

      buffer.rewind

      begin
        xml = XML.parse(buffer, options: XML::ParserOptions::RECOVER | XML::ParserOptions::NOENT)

        unless xml.root
          return build_error_result("No root element")
        end

        rss = parse_rss(xml)
        return rss unless rss.entries.empty?

        atom = parse_atom(xml)
        return atom unless atom.entries.empty?

        build_error_result("Unsupported feed format")
      rescue ex : XML::Error
        build_error_result("XML parsing error: #{ex.message}")
      rescue ex
        build_error_result("Error: #{ex.class} - #{ex.message}")
      end
    end

    private def parse_rss(xml : XML::Node) : Result
      site_link = "#"
      entries = [] of Entry

      is_rdf = xml.root.try(&.name) == "RDF"

      if is_rdf
        if channel = xml.xpath_node("//*[local-name()='channel']")
          site_link = resolve_rss_site_link(channel)
        end
        xml.xpath_nodes("//*[local-name()='item']").each do |node|
          entries << parse_rss_item(node)
        end
      else
        if channel = xml.xpath_node("//*[local-name()='channel']")
          site_link = resolve_rss_site_link(channel)
          channel.xpath_nodes("./*[local-name()='item']").each do |node|
            entries << parse_rss_item(node)
          end
        end
      end

      favicon = xml.xpath_node("//*[local-name()='channel']/*[local-name()='image']/*[local-name()='url']").try(&.text)

      Result.new(
        entries: entries,
        etag: nil,
        last_modified: nil,
        site_link: site_link,
        favicon: favicon,
        error_message: nil
      )
    end

    private def resolve_rss_site_link(channel : XML::Node) : String
      links = channel.xpath_nodes("./*[local-name()='link']")
      site_link_node = links.find do |node|
        node["rel"]? != "self" && (node.text.presence || node["href"]?)
      end || links.first?

      return "#" unless site_link_node
      link = site_link_node["href"]? || site_link_node.text
      link.strip.presence || "#"
    end

    private def parse_rss_item(node : XML::Node) : Entry
      title = node.xpath_node("./*[local-name()='title']").try(&.text).try(&.strip)
      title = HTML.unescape(title) if title
      title = "Untitled" if title.nil? || title.empty?

      link = node.xpath_node("./*[local-name()='link']").try(&.text) || "#"

      pub_date_str = node.xpath_node("./*[local-name()='pubDate']").try(&.text) ||
                     node.xpath_node("./*[local-name()='dc:date']").try(&.text) ||
                     node.xpath_node("./*[local-name()='date']").try(&.text)
      pub_date = parse_time(pub_date_str)

      Entry.new(title, link, "", nil, pub_date, "rss", nil)
    end

    private def parse_atom(xml : XML::Node) : Result
      entries = [] of Entry

      feed_node = xml.xpath_node("//*[local-name()='feed']")
      return build_error_result("No feed element") unless feed_node

      alt = feed_node.xpath_node("./*[local-name()='link'][@rel='alternate' and (not(@type) or starts-with(@type,'text/html'))]") ||
            feed_node.xpath_node("./*[local-name()='link'][@rel='alternate']") ||
            feed_node.xpath_node("./*[local-name()='link'][not(@rel) and @href]") ||
            feed_node.xpath_node("./*[local-name()='link'][@href]")
      site_link = alt.try(&.[]?("href")).try(&.strip) || alt.try(&.text).try(&.strip)

      feed_node.xpath_nodes("./*[local-name()='entry']").each do |node|
        entries << parse_atom_entry(node)
      end

      favicon = feed_node.xpath_node("./*[local-name()='icon']").try(&.text) ||
                feed_node.xpath_node("./*[local-name()='logo']").try(&.text)

      Result.new(
        entries: entries,
        etag: nil,
        last_modified: nil,
        site_link: site_link,
        favicon: favicon,
        error_message: nil
      )
    end

    private def parse_atom_entry(node : XML::Node) : Entry
      title = node.xpath_node("./*[local-name()='title']").try(&.text).try(&.strip)
      title = HTML.unescape(title) if title
      title = "Untitled" if title.nil? || title.empty?

      link_node = node.xpath_node("./*[local-name()='link'][@rel='alternate' and (not(@type) or starts-with(@type,'text/html'))]") ||
                  node.xpath_node("./*[local-name()='link'][@rel='alternate']") ||
                  node.xpath_node("./*[local-name()='link'][@href]") ||
                  node.xpath_node("./*[local-name()='link']")
      link = link_node.try(&.[]?("href")) || link_node.try(&.text).try(&.strip) || "#"

      published_str = node.xpath_node("./*[local-name()='published']").try(&.text) ||
                      node.xpath_node("./*[local-name()='updated']").try(&.text)
      pub_date = parse_time(published_str)

      Entry.new(title, link, "", nil, pub_date, "atom", nil)
    end

    private def parse_time(time_str : String?) : Time?
      return nil unless time_str

      formats = [
        "%a, %d %b %Y %H:%M:%S %z",
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M:%SZ",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d",
      ]

      formats.each do |fmt|
        begin
          return Time.parse(time_str.strip, fmt, Time::Location::UTC)
        rescue
        end
      end

      begin
        return Time.parse_iso8601(time_str.strip)
      rescue
      end

      nil
    end
  end
end

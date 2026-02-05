require "xml"
require "html"

# Maximum feed size to prevent memory exhaustion
MAX_FEED_SIZE = 5 * 1024 * 1024 # 5MB

def parse_feed(io : IO, limit : Int32) : {site_link: String?, items: Array(Item), favicon: String?}
  # Buffer raw bytes to allow libxml2 to detect encoding from the XML declaration.
  # NOENT substitutes entities (like &Yuml;) during parsing.
  buffer = IO::Memory.new

  # Limit feed size to prevent memory exhaustion
  bytes_copied = IO.copy(io, buffer, limit: MAX_FEED_SIZE)

  # If feed is too large, log and return empty
  if bytes_copied >= MAX_FEED_SIZE
    STDERR.puts "[WARN] Feed too large (>5MB), skipping parsing"
    return {site_link: "#", items: [] of Item, favicon: nil}
  end

  buffer.rewind

  # Parse with timeout protection and error handling
  begin
    xml = XML.parse(buffer, options: XML::ParserOptions::RECOVER | XML::ParserOptions::NOENT)

    # Validate XML structure
    unless xml.root
      STDERR.puts "[WARN] Feed has no root element, skipping"
      return {site_link: "#", items: [] of Item, favicon: nil}
    end

    rss = parse_rss(xml, limit)
    return rss unless rss[:items].empty?
    atom = parse_atom(xml, limit)
    return atom unless atom[:items].empty?
    {site_link: "#", items: [] of Item, favicon: nil}
  rescue ex : XML::Error
    STDERR.puts "[ERROR] XML parsing error: #{ex.message}"
    {site_link: "#", items: [] of Item, favicon: nil}
  rescue ex : Exception
    STDERR.puts "[ERROR] Unexpected error parsing feed: #{ex.class} - #{ex.message}"
    STDERR.puts ex.backtrace.join("\n") if ex.backtrace
    {site_link: "#", items: [] of Item, favicon: nil}
  end
end

private def parse_rss(xml : XML::Node, limit : Int32) : {site_link: String, items: Array(Item), favicon: String?}
  site_link = "#"
  items = [] of Item

  # Check if this is an RDF/RSS feed (items are siblings of channel, not children)
  is_rdf = xml.root.try(&.name) == "RDF"

  if is_rdf
    # For RDF/RSS format, find channel and items at root level
    if channel = xml.xpath_node("//*[local-name()='channel']")
      site_link = resolve_rss_site_link(channel)
    end

    # In RDF, items are at root level, not inside channel
    xml.xpath_nodes("//*[local-name()='item']").each do |node|
      items << parse_rss_item(node)
      break if items.size >= limit
    end
  else
    # Standard RSS format
    if channel = xml.xpath_node("//*[local-name()='channel']")
      site_link = resolve_rss_site_link(channel)

      channel.xpath_nodes("./*[local-name()='item']").each do |node|
        items << parse_rss_item(node)
        break if items.size >= limit
      end
    end
  end

  favicon = xml.xpath_node("//*[local-name()='channel']/*[local-name()='image']/*[local-name()='url']").try(&.text)
  {site_link: site_link, items: items, favicon: favicon}
end

private def resolve_rss_site_link(channel : XML::Node) : String
  # Prefer the link that isn't the atom:link "self" and handle both text content and href attributes
  links = channel.xpath_nodes("./*[local-name()='link']")
  site_link_node = links.find do |node|
    node["rel"]? != "self" && (node.text.presence || node["href"]?)
  end || links.first?

  return "#" unless site_link_node

  link = site_link_node["href"]? || site_link_node.text
  link.strip.presence || "#"
end

private def parse_rss_item(node : XML::Node) : Item
  title = node.xpath_node("./*[local-name()='title']").try(&.text).try(&.strip)
  title = HTML.unescape(title) if title
  title = "Untitled" if title.nil? || title.empty?

  link = node.xpath_node("./*[local-name()='link']").try(&.text) || "#"

  # Try pubDate first, then dc:date (Dublin Core), then other date elements
  pub_date_str = node.xpath_node("./*[local-name()='pubDate']").try(&.text) ||
                 node.xpath_node("./*[local-name()='dc:date']").try(&.text) ||
                 node.xpath_node("./*[local-name()='date']").try(&.text) ||
                 node.xpath_node(".//*[local-name()='dc:date']").try(&.text) ||
                 node.xpath_node(".//*[local-name()='date']").try(&.text)
  pub_date = parse_time(pub_date_str)

  Item.new(title, link, pub_date)
end

private def parse_atom_entry(node : XML::Node) : Item
  # Title text
  title = node.xpath_node("./*[local-name()='title']").try(&.text).try(&.strip)
  title = HTML.unescape(title) if title
  title = "Untitled" if title.nil? || title.empty?

  # Entry link preference: rel="alternate" (type text/html) -> any link with href -> text content
  link_node = node.xpath_node("./*[local-name()='link'][@rel='alternate' and (not(@type) or starts-with(@type,'text/html'))]") ||
              node.xpath_node("./*[local-name()='link'][@rel='alternate']") ||
              node.xpath_node("./*[local-name()='link'][@href]") ||
              node.xpath_node("./*[local-name()='link']")
  link = link_node.try(&.[]?("href")) || link_node.try(&.text).try(&.strip) || "#"

  published_str = node.xpath_node("./*[local-name()='published']").try(&.text) ||
                  node.xpath_node("./*[local-name()='updated']").try(&.text)
  pub_date = parse_time(published_str)

  Item.new(title, link, pub_date)
end

private def parse_atom(xml : XML::Node, limit : Int32) : {site_link: String?, items: Array(Item), favicon: String?}
  items = [] of Item

  # FIX: correct XPath string
  feed_node = xml.xpath_node("//*[local-name()='feed']")
  return {site_link: nil, items: items, favicon: nil} unless feed_node

  # Site link preference: rel="alternate" (type text/html) -> first link with href -> keep default
  # Also handle links without a rel attribute (like Slashdot)
  alt = feed_node.xpath_node("./*[local-name()='link'][@rel='alternate' and (not(@type) or starts-with(@type,'text/html'))]") ||
        feed_node.xpath_node("./*[local-name()='link'][@rel='alternate']") ||
        feed_node.xpath_node("./*[local-name()='link'][not(@rel) and @href]") ||
        feed_node.xpath_node("./*[local-name()='link'][@href]")
  site_link = alt.try(&.[]?("href")).try(&.strip) || alt.try(&.text).try(&.strip)

  # Entries
  feed_node.xpath_nodes("./*[local-name()='entry']").each do |node|
    items << parse_atom_entry(node)
    break if items.size >= limit
  end

  favicon = feed_node.xpath_node("./*[local-name()='icon']").try(&.text) ||
            feed_node.xpath_node("./*[local-name()='logo']").try(&.text)
  {site_link: site_link, items: items, favicon: favicon}
end

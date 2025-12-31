require "xml"
require "html"

def parse_feed(io : IO, limit : Int32) : {site_link: String, items: Array(Item), favicon: String?}
  # Buffer raw bytes to allow libxml2 to detect encoding from the XML declaration.
  # NOENT substitutes entities (like &Yuml;) during parsing.
  buffer = IO::Memory.new
  # Limit feed size to 5MB
  IO.copy(io, buffer, limit: 5 * 1024 * 1024)
  buffer.rewind

  xml = XML.parse(buffer, options: XML::ParserOptions::RECOVER | XML::ParserOptions::NOENT)
  rss = parse_rss(xml, limit)
  return rss unless rss[:items].empty?
  atom = parse_atom(xml, limit)
  return atom unless atom[:items].empty?
  {site_link: "#", items: [] of Item, favicon: nil}
rescue
  {site_link: "#", items: [] of Item, favicon: nil}
end

private def parse_rss(xml : XML::Node, limit : Int32) : {site_link: String, items: Array(Item), favicon: String?}
  site_link = "#"
  items = [] of Item
  if channel = xml.xpath_node("//*[local-name()='channel']")
    # Prefer the link that isn't the atom:link "self" and handle both text content and href attributes
    links = channel.xpath_nodes("./*[local-name()='link']")
    site_link_node = links.find { |n| n["rel"]? != "self" && (n.text.presence || n["href"]?) } || links.first?
    site_link = site_link_node.try { |n| n["href"]? || n.text }.try(&.strip) || site_link

    channel.xpath_nodes("./*[local-name()='item']").each do |node|
      title = node.xpath_node("./*[local-name()='title']").try(&.text).try(&.strip)
      title = HTML.unescape(title) if title
      title = "Untitled" if title.nil? || title.empty?

      link = node.xpath_node("./*[local-name()='link']").try(&.text) || "#"
      pub_date = parse_time(node.xpath_node("./*[local-name()='pubDate']").try(&.text))
      items << Item.new(title, link, pub_date)
      break if items.size >= limit
    end
  end
  favicon = xml.xpath_node("//*[local-name()='channel']/*[local-name()='image']/*[local-name()='url']").try(&.text)
  {site_link: site_link, items: items, favicon: favicon}
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

private def parse_atom(xml : XML::Node, limit : Int32) : {site_link: String, items: Array(Item), favicon: String?}
  site_link = "#"
  items = [] of Item

  # FIX: correct XPath string
  feed_node = xml.xpath_node("//*[local-name()='feed']")
  return {site_link: site_link, items: items, favicon: nil} unless feed_node

  # Site link preference: rel="alternate" (type text/html) -> first link with href -> keep default
  alt = feed_node.xpath_node("./*[local-name()='link'][@rel='alternate' and (not(@type) or starts-with(@type,'text/html'))]") ||
        feed_node.xpath_node("./*[local-name()='link'][@rel='alternate']") ||
        feed_node.xpath_node("./*[local-name()='link'][@href]")
  site_link = alt.try(&.[]?("href")).try(&.strip) || alt.try(&.text).try(&.strip) || site_link

  # Entries
  feed_node.xpath_nodes("./*[local-name()='entry']").each do |node|
    items << parse_atom_entry(node)
    break if items.size >= limit
  end

  favicon = feed_node.xpath_node("./*[local-name()='icon']").try(&.text) ||
            feed_node.xpath_node("./*[local-name()='logo']").try(&.text)
  {site_link: site_link, items: items, favicon: favicon}
end

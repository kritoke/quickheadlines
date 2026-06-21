## RSS 2.0 / Atom parser - promoted from the Phase-1 spike.
## Uses std/xmltree + std/xmlparser (no libxml2 dep). Returns a FetchResult
## (okFetch / errFetch(feParse)). Sole place that knows the feed XML shape.

import std/[streams, strutils, xmltree, xmlparser, times]
import ../types

const DbTimeFormat = "yyyy-MM-dd HH:mm:ss"   # SQLite stores pub_date as this string

proc normalizePubDate*(s: string): string =
  ## RSS pubDates come as RFC822 ("Tue, 19 Jun 2026 15:30:00 +0000") or ISO
  ## ("2026-06-19T15:30:00Z"). Normalise to "yyyy-MM-dd HH:mm:ss" so the
  ## timeline's string-comparison filters work (matches Crystal, which parses
  ## to Time then formats). "" if unparseable.
  if s.len == 0: return ""
  var ss = s.strip()
  if ss.len > 5 and ss[3] == ',' and ss[4] == ' ': ss = ss[5..^1]   # drop "Tue, "
  # Drop a trailing timezone token ("+0000", "-0500", "GMT", "UTC", "Z").
  let parts = ss.splitWhitespace()
  if parts.len >= 5 and (parts[4][0] in {'+', '-'} or parts[4] in ["GMT", "UTC", "Z"]):
    ss = parts[0..3].join(" ")
  for f in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "dd MMM yyyy HH:mm:ss",
            "yyyy-MM-dd", "dd MMM yyyy"]:
    try:
      return parse(ss, f, utc()).format(DbTimeFormat)
    except TimeParseError, ValueError:
      discard
  ""

proc allText(n: XmlNode): string =
  ## innerText() skips xnCData (Nim 2.2.4); this collects text AND CDATA
  ## content, so titles/descriptions wrapped in <![CDATA[...]]> parse correctly.
  case n.kind
  of xnText, xnVerbatimText, xnComment, xnCData, xnEntity: result.add(n.text)
  else:
    for c in n: result.add(c.allText)

proc childText*(n: XmlNode; tag: string): string =
  let c = n.child(tag)
  if c == nil: "" else: c.allText.strip()

proc linkOf*(n: XmlNode): string =
  ## Extract the link URL from an item. Handles both:
  ## - RSS: <link>http://example.com/article</link>  (text content)
  ## - Atom: <link href="http://example.com/article"/>  (href attribute)
  let c = n.child("link")
  if c == nil: return ""
  # Try href attribute first (Atom-style: <link href="..." rel="alternate"/>).
  let h = c.attr("href")
  if h.len > 0: return h.strip()
  # Fall back to text content (RSS-style: <link>http://...</link>).
  c.allText.strip()

proc parseRss*(url, body: string): FetchResult =
  ## Parse RSS 2.0 (or Atom <feed>) into FeedData. Any parse error -> feParse.
  try:
    let tree = parseXml(newStringStream(body))
    var fd = FeedData(url: url)
    # RSS 2.0: <rss><channel>...; Atom: <feed> (may have namespace).
    # Strip namespace from the tag for comparison: "{http://...}feed" -> "feed".
    let rawTag = tree.tag
    let bareTag = if rawTag.contains('}'): rawTag[rawTag.find('}') + 1 .. ^1] else: rawTag
    let root =
      if bareTag in ["rss", "feed"]: tree
      elif bareTag == "channel": tree
      else: tree.child("channel")
    if root != nil:
      let rootTag = if root.tag.contains('}'): root.tag[root.tag.find('}') + 1 .. ^1] else: root.tag
      if rootTag == "feed":               # Atom
        fd.title = root.childText("title")
        for it in root.findAll("entry"):
          fd.items.add Item(
            title: it.childText("title"),
            link: it.linkOf,
            pubDate: normalizePubDate(it.childText("updated")))
      else:                                 # RSS 2.0
        let channel = if root.tag == "channel": root else: root.child("channel")
        if channel != nil:
          fd.title = channel.childText("title")
          for it in channel.findAll("item"):
            fd.items.add Item(
              title: it.childText("title"),
              link: it.linkOf,
              pubDate: normalizePubDate(it.childText("pubDate")))
      okFetch(fd)
    else:
      okFetch(fd)   # parsed but no known root; return empty (not a parse error)
  except CatchableError:
    errFetch(feParse)

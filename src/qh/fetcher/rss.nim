## RSS 2.0 / Atom parser - promoted from the Phase-1 spike.
## Uses std/xmltree + std/xmlparser (no libxml2 dep). Returns a FetchResult
## (okFetch / errFetch(feParse)). Sole place that knows the feed XML shape.

import std/[streams, strutils, xmltree, xmlparser, times]
from unicode import Rune, toUTF8
import ../types

const DbTimeFormat = "yyyy-MM-dd HH:mm:ss"

proc decodeHtmlEntities*(s: string): string =
  ## Decode HTML numeric character references (&#NNN; and &#xHHHH;) that the
  ## XML parser leaves raw inside CDATA sections.  Also handles the common
  ## named entities that RSS feeds use.
  result = s
  var res = newStringOfCap(s.len)
  var i = 0
  while i < s.len:
    if s[i] == '&' and (i + 2 < s.len):
      if s[i+1] == '#':
        # Numeric entity: &#NNN; or &#xHHHH;
        let semi = s.find(';', i + 2)
        if semi > i + 1:
          let numStr = s[i+2 ..< semi]
          var codepoint: int
          if numStr.len > 0 and numStr[0] == 'x':
            codepoint = parseHexInt(numStr[1..^1])
          else:
            codepoint = parseInt(numStr)
          res.add(Rune(codepoint).toUTF8)
          i = semi + 1
          continue
      elif s[i+1..^1].startsWith("amp;"):
        res.add('&'); i += 5; continue
      elif s[i+1..^1].startsWith("lt;"):
        res.add('<'); i += 4; continue
      elif s[i+1..^1].startsWith("gt;"):
        res.add('>'); i += 4; continue
      elif s[i+1..^1].startsWith("quot;"):
        res.add('"'); i += 6; continue
      elif s[i+1..^1].startsWith("apos;"):
        res.add('\''); i += 6; continue
    res.add(s[i])
    i += 1
  result = res   # SQLite stores pub_date as this string

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
  case n.kind
  of xnText, xnVerbatimText, xnComment, xnCData, xnEntity: result.add(n.text)
  else:
    for c in n: result.add(c.allText)

proc bareTag(n: XmlNode): string =
  let t = n.tag
  if t.contains('}'): t[t.find('}') + 1 .. ^1] else: t

proc childNs*(n: XmlNode; tag: string): XmlNode =
  for c in n:
    if c.bareTag == tag: return c

proc findAllNs*(n: XmlNode; tag: string): seq[XmlNode] =
  for c in n:
    if c.bareTag == tag: result.add(c)

proc childText*(n: XmlNode; tag: string): string =
  let c = n.childNs(tag)
  if c == nil: "" else: decodeHtmlEntities(c.allText.strip())

proc linkOf*(n: XmlNode): string =
  let c = n.childNs("link")
  if c == nil: return ""
  let h = c.attr("href")
  if h.len > 0: return h.strip()
  c.allText.strip()

proc parseRss*(url, body: string): FetchResult =
  try:
    let tree = parseXml(newStringStream(body))
    var fd = FeedData(url: url)
    let bare = tree.bareTag
    let root =
      if bare in ["rss", "feed"]: tree
      elif bare == "channel": tree
      else: tree.childNs("channel")
    if root != nil:
      if root.bareTag == "feed":
        fd.title = root.childText("title")
        fd.siteLink = root.linkOf
        for it in root.findAllNs("entry"):
          fd.items.add Item(
            title: it.childText("title"),
            link: it.linkOf,
            pubDate: normalizePubDate(it.childText("updated")))
      else:
        let channel = if root.bareTag == "channel": root else: root.childNs("channel")
        if channel != nil:
          fd.title = channel.childText("title")
          fd.siteLink = channel.linkOf
          for it in channel.findAllNs("item"):
            fd.items.add Item(
              title: it.childText("title"),
              link: it.linkOf,
              pubDate: normalizePubDate(it.childText("pubDate")))
      okFetch(fd)
    else:
      okFetch(fd)
  except CatchableError:
    errFetch(feParse)

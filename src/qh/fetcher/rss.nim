## RSS 2.0 / Atom parser - promoted from the Phase-1 spike.
## Uses std/xmltree + std/xmlparser (no libxml2 dep). Returns a FetchResult
## (okFetch / errFetch(feParse)). Sole place that knows the feed XML shape.

import std/[streams, strutils, xmltree, xmlparser]
import ../types

proc childText*(n: XmlNode; tag: string): string =
  let c = n.child(tag)
  if c == nil: "" else: c.innerText.strip()

proc parseRss*(url, body: string): FetchResult =
  ## Parse RSS 2.0 (or Atom <feed>) into FeedData. Any parse error -> feParse.
  try:
    let tree = parseXml(newStringStream(body))
    var fd = FeedData(url: url)
    # RSS 2.0: <rss><channel>...; Atom: <feed>.
    let root =
      if tree.tag in ["rss", "feed"]: tree
      elif tree.tag == "channel": tree
      else: tree.child("channel")
    if root != nil:
      if root.tag == "feed":               # Atom
        fd.title = root.childText("title")
        for it in root.findAll("entry"):
          fd.items.add Item(
            title: it.childText("title"),
            link: it.childText("link"),
            pubDate: it.childText("updated"))
      else:                                 # RSS 2.0
        let channel = if root.tag == "channel": root else: root.child("channel")
        if channel != nil:
          fd.title = channel.childText("title")
          for it in channel.findAll("item"):
            fd.items.add Item(
              title: it.childText("title"),
              link: it.childText("link"),
              pubDate: it.childText("pubDate"))
      okFetch(fd)
    else:
      okFetch(fd)   # parsed but no known root; return empty (not a parse error)
  except CatchableError:
    errFetch(feParse)

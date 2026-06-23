## URL normalizer - port of src/utils/url_normalizer.cr.
## Normalizes URLs for the UNIQUE(feed_id, normalized_link) dedup constraint.
## Strips tracking params (40+), www. prefix, feed suffixes, fragments.
## Lowercases scheme/host. Removes standard ports.

import std/[uri, strutils, sets, re]

const TrackingParams = [
  # UTM (7)
  "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
  "utm_reader", "utm_viz_id", "utm_pubreferrer", "utm_swu",
  # Common tracking (8)
  "fbclid", "gclid", "gclsrc", "dclid", "msclkid", "mc_cid", "mc_eid",
  "_ga", "_gl",
  # Referral/source (6)
  "ref", "referrer", "referer", "source", "via", "campaign",
  # Social (3)
  "igshid", "twclid", "li_fat_id",
  # Affiliate (2)
  "affiliate", "partner",
  # Click tracking (2)
  "clickid", "sessionid",
  # Other (3)
  "mkt_tok", "trk", "trkInfo",
  # Reddit (3)
  "context", "depth", "embed",
  # Hacker News (2)
  "focusedCommentId", "commentInformTab",
  # StackOverflow (4)
  "answertab", "votes", "pagesize", "sort",
  # Google (4)
  "sa", "ved", "ei", "usg",
  # News (3)
  "outputType", "pageType", "pf",
]

const FeedSuffixes = [
  "/feed.xml", "/rss.xml", "/feed", "/rss", "/atom.xml",
  "/rss2.xml", "/feed/", "/rss/", "/atom/",
]

proc buildTrackingSet(): HashSet[string] =
  result = initHashSet[string]()
  for p in TrackingParams: result.incl(p)

let trackingSet = buildTrackingSet()

proc stripFeedSuffix(path: string): string =
  ## Strip common feed suffixes from path (/feed.xml, /rss, etc.).
  result = path
  for suffix in FeedSuffixes:
    if result.endsWith(suffix):
      result = result[0 ..< result.len - suffix.len]
      break
  if result.len == 0: result = "/"

proc stripWww(host: string): string =
  ## Strip www. prefix from hostname.
  if host.startsWith("www.") and host.len > 4:
    host[4 .. ^1]
  else:
    host

proc normalizeQuery(query: string): string =
  ## Remove ALL query params except known content params.
  ## This matches the old behavior (strip everything) while preserving
  ## params that carry unique content identity.
  if query.len == 0: return ""
  # Known content-bearing params that should be preserved.
  const KeepParams = ["id", "p", "page", "article", "post", "entry", "slug"]
  var keep: seq[string]
  for part in query.split('&'):
    if part.len == 0: continue
    let eqIdx = part.find('=')
    let key = if eqIdx >= 0: part[0 ..< eqIdx] else: part
    let val = if eqIdx >= 0: part[eqIdx+1 .. ^1] else: ""
    if key.len == 0: continue
    # Keep known content params; strip everything else.
    if key.toLowerAscii() in KeepParams and val.len > 0:
      keep.add(part)
  if keep.len == 0: "" else: keep.join("&")

proc normalizeUrl*(url: string): string =
  ## Full URL normalization for dedup. Strips tracking params, www., feed
  ## suffixes, fragments. Lowercases scheme/host. Removes standard ports.
  if url.len == 0: return ""
  try:
    var p = parseUri(url.strip())
    if p.hostname.len == 0: return url.strip()   # relative URL; leave as-is
    p.scheme = p.scheme.toLowerAscii()
    p.hostname = stripWww(p.hostname.toLowerAscii())
    # Remove standard ports.
    if (p.scheme == "http" and p.port == "80") or
       (p.scheme == "https" and p.port == "443"):
      p.port = ""
    # Strip feed suffixes from path.
    p.path = stripFeedSuffix(p.path)
    # Strip trailing slash (unless root).
    if p.path.len > 1 and p.path.endsWith("/"):
      p.path = p.path[0 .. ^2]
    # Remove tracking params.
    p.query = normalizeQuery(p.query)
    # Always drop fragment.
    p.anchor = ""
    # Rebuild.
    var result = p.scheme & "://" & p.hostname
    if p.port.len > 0: result &= ":" & p.port
    result &= p.path
    if p.query.len > 0: result &= "?" & p.query
    result
  except CatchableError:
    url.strip()

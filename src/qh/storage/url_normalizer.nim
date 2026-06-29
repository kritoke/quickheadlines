## URL normalizer - port of src/utils/url_normalizer.cr.
## Normalizes URLs for the UNIQUE(feed_id, normalized_link) dedup constraint.
## Strips ALL query params except a small content-bearing allowlist (id, p,
## page, article, post, entry, slug), www. prefix, feed suffixes, fragments.
## Lowercases scheme/host. Removes standard ports.
##
## NOTE: an earlier revision kept a 47-entry TrackingParams blocklist, but it
## was never wired into normalizeUrl — the allowlist approach (drop everything
## not in KeepParams) is stricter and is what shipped, so the blocklist is gone.

import std/[uri, strutils]

const FeedSuffixes = [
  "/feed.xml", "/rss.xml", "/feed", "/rss", "/atom.xml",
  "/rss2.xml", "/feed/", "/rss/", "/atom/",
]

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
    var urlResult = p.scheme & "://" & p.hostname
    if p.port.len > 0: urlResult &= ":" & p.port
    urlResult &= p.path
    if p.query.len > 0: urlResult &= "?" & p.query
    urlResult
  except CatchableError:
    url.strip()

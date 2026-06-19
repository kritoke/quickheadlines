## URL normalizer - port of src/utils/url_normalizer.cr.
## Strips query string and fragment unconditionally (same behaviour as the
## Crystal original; see planning/context.md finding #19). Used to derive
## `normalized_link` so the UNIQUE(feed_id, normalized_link) constraint dedups.

import std/uri

proc normalizeUrl*(url: string): string =
  ## scheme://host[:port]/path  (query and fragment dropped).
  if url.len == 0: return ""
  try:
    let p = parseUri(url)
    if p.hostname.len == 0: return url   # not a proper absolute URL; leave as-is
    let scheme = if p.scheme.len > 0: p.scheme else: "http"
    let auth = if p.port.len > 0: p.hostname & ":" & p.port else: p.hostname
    scheme & "://" & auth & p.path
  except CatchableError:
    url   # fall back to the raw link if unparseable

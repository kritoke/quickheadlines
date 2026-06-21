## Software release fetcher - fetches releases from GitHub/GitLab/Codeberg repos
## and returns them as a single FeedData suitable for inclusion in /api/feeds.
##
## Uses the .atom RSS feeds that all three providers serve (no HTML scraping).
## Repo format: "owner/repo" (default GitHub) or "owner/repo:provider" where
## provider is gh (GitHub), gl (GitLab), cb (Codeberg).

import std/[strutils, algorithm, httpclient]
import ../types
import ./rss

const
  SwUrl* = "software://releases"

proc repoToAtomUrl(entry: string): string =
  let parts = entry.split(':')
  let repoPath = parts[0]
  let provider = if parts.len > 1: parts[1] else: "gh"
  case provider
  of "gh": "https://github.com/" & repoPath & "/releases.atom"
  of "gl": "https://gitlab.com/" & repoPath & "/-/releases.atom"
  of "cb": "https://codeberg.org/" & repoPath & "/releases.atom"
  else: "https://github.com/" & repoPath & "/releases.atom"

proc repoName(entry: string): string =
  ## "owner/repo:gh" -> "repo"
  let parts = entry.split(':')
  let repoPath = parts[0]
  let segs = repoPath.split('/')
  if segs.len >= 2: segs[^1] else: repoPath

proc isVersionString(s: string): bool =
  ## "v1.0.0" or "1.0.0" -> true (starts with digit or 'v'/'V' + digit)
  if s.len == 0: return false
  let s2 = s.strip()
  if s2.len == 0: return false
  if s2[0] in {'0'..'9'}: return true
  if s2[0] in {'v', 'V'} and s2.len > 1 and s2[1] in {'0'..'9'}: return true
  false

proc fixSoftwareTitle*(title, repoEntry: string): string =
  ## Prepend repo name to version-only titles (port of Crystal fix_software_title).
  let repo = repoName(repoEntry)
  let t = title.strip()
  if t.isVersionString:
    return repo & " " & t
  t

proc fetchSoftwareReleases*(repos: seq[string]): FeedData =
  result = FeedData(
    title: "Software Updates",
    url: SwUrl,
    siteLink: "https://github.com")
  for repo in repos:
    if repo.len == 0: continue
    let url = repoToAtomUrl(repo)
    try:
      let client = newHttpClient(timeout = 10000)
      let resp = client.request(url, HttpGet)
      if resp.code.int == 200:
        let fd = rss.parseRss(url, resp.body)
        if fd.isOk and fd.data.items.len > 0:
          # Take only the LATEST release (first in Atom feed, already sorted by date).
          var item = fd.data.items[0]
          item.title = fixSoftwareTitle(item.title, repo)
          result.items.add(item)
      client.close()
    except CatchableError as e:
      echo "[sw-releases] ", repo, " failed: ", e.msg
      discard
  # Sort combined results by pub_date descending.
  result.items.sort do (a, b: Item) -> int:
    b.pubDate.cmp(a.pubDate)

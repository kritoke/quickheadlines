## Software release fetcher - fetches releases from GitHub/GitLab/Codeberg repos
## and returns them as a single FeedData suitable for inclusion in /api/feeds.
##
## Uses the .atom RSS feeds that all three providers serve (no HTML scraping).
## Repo format: "owner/repo" (default GitHub) or "owner/repo:provider" where
## provider is gh (GitHub), gl (GitLab), cb (Codeberg).

import std/[strutils, algorithm, tables, sequtils, httpclient]
import ../types
import ./rss

const
  SwUrl* = "software://releases"
  MaxItems* = 50

proc repoToAtomUrl(entry: string): string =
  ## "owner/repo:gl" -> "https://gitlab.com/owner/repo/-/releases.atom"
  let parts = entry.split(':')
  let repoPath = parts[0]
  let provider = if parts.len > 1: parts[1] else: "gh"
  case provider
  of "gh": "https://github.com/" & repoPath & "/releases.atom"
  of "gl": "https://gitlab.com/" & repoPath & "/-/releases.atom"
  of "cb": "https://codeberg.org/" & repoPath & "/releases.atom"
  else: "https://github.com/" & repoPath & "/releases.atom"

proc repoToOrigin(entry: string): string =
  ## "owner/repo:gh" -> "https://github.com"
  let parts = entry.split(':')
  let provider = if parts.len > 1: parts[1] else: "gh"
  case provider
  of "gh": "https://github.com"
  of "gl": "https://gitlab.com"
  of "cb": "https://codeberg.org"
  else: "https://github.com"

proc fetchSoftwareReleases*(repos: seq[string]): FeedData =
  ## Fetch releases from all repos, combine into a single FeedData.
  ## Uses sync RSS parsing (same as the feed fetcher). Best-effort per repo.
  result = FeedData(
    title: "Software Updates",
    url: SwUrl,
    siteLink: "https://github.com")
  for repo in repos:
    if repo.len == 0: continue
    let url = repoToAtomUrl(repo)
    let origin = repoToOrigin(repo)
    try:
      let client = newHttpClient(timeout = 10000)
      let resp = client.request(url, HttpGet)
      if resp.code.int == 200:
        let fd = rss.parseRss(url, resp.body)
        if fd.isOk:
          for it in fd.data.items:
            result.items.add(it)
      client.close()
    except CatchableError:
      discard
  # Sort by pub_date descending, keep top N.
  result.items.sort do (a, b: Item) -> int:
    b.pubDate.cmp(a.pubDate)
  if result.items.len > MaxItems:
    result.items = result.items[0 ..< MaxItems]

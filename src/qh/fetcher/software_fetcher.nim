## Software release fetcher - port of Crystal src/software_fetcher.cr + lib/fetcher/.
## Fetches releases from GitHub/GitLab/Codeberg repos. Tries JSON API first
## (provider-specific), falls back to Atom feed. Returns a single FeedData
## suitable for inclusion in /api/feeds.
##
## Repo format: "owner/repo" (default GitHub) or "owner/repo:provider" where
## provider is gh (GitHub), gl (GitLab), cb (Codeberg).

import std/[strutils, algorithm, httpclient, json, uri]
import ../types
import ./rss

const
  SwUrl* = "software://releases"
  UserAgent* = "Mozilla/5.0 (compatible; QuickHeadlines/1.0)"

proc repoPath(entry: string): string =
  let parts = entry.split(':')
  parts[0]

proc provider(entry: string): string =
  let parts = entry.split(':')
  if parts.len > 1: parts[1] else: "gh"

proc repoName(entry: string): string =
  ## "owner/repo:gh" -> "repo"
  let segs = repoPath(entry).split('/')
  if segs.len >= 2: segs[^1] else: repoPath(entry)

proc encodeRepo(repo: string): string =
  ## URL-encode owner/repo for API paths (e.g. "group/sub/repo" -> "group%2Fsub%2Frepo").
  encodeUrl(repo, usePlus = false)

proc isVersionString(s: string): bool =
  if s.len == 0: return false
  let s2 = s.strip()
  if s2.len == 0: return false
  if s2[0] in {'0'..'9'}: return true
  if s2[0] in {'v', 'V'} and s2.len > 1 and s2[1] in {'0'..'9'}: return true
  false

proc fixSoftwareTitle*(title, repoEntry: string): string =
  let repo = repoName(repoEntry)
  let t = title.strip()
  if t.isVersionString: return repo & " " & t
  t

proc httpGet(url: string): (int, string) =
  try:
    let client = newHttpClient(timeout = 10000, maxRedirects = 5)
    client.headers = newHttpHeaders({
      "User-Agent": UserAgent,
      "Accept": "application/json, application/atom+xml, application/xml",
      "Accept-Encoding": "identity"})
    let resp = client.request(url, HttpGet)
    client.close()
    (resp.code.int, resp.body)
  except CatchableError as e:
    (0, e.msg)

# ---- GitHub API ----
proc fetchGitHubApi(repo: string): seq[Item] =
  let url = "https://api.github.com/repos/" & repo & "/releases"
  let (code, body) = httpGet(url)
  if code != 200: return
  try:
    let arr = parseJson(body)
    for rel in arr:
      if rel{"prerelease"}.getBool(false) or rel{"draft"}.getBool(false): continue
      let tag = rel{"tag_name"}.getStr("")
      let name = rel{"name"}.getStr("")
      let link = rel{"html_url"}.getStr("")
      let pubDate = rel{"published_at"}.getStr("")
      let title = if name.len > 0: name elif tag.len > 0: tag else: repo
      result.add Item(
        title: title, link: link,
        pubDate: rss.normalizePubDate(pubDate))
  except CatchableError:
    discard

# ---- GitLab API ----
proc fetchGitLabApi(repo: string): seq[Item] =
  let encoded = encodeRepo(repo)
  let domain = "gitlab.com"
  let url = "https://" & domain & "/api/v4/projects/" & encoded & "/releases"
  let (code, body) = httpGet(url)
  if code != 200: return
  try:
    let arr = parseJson(body)
    for rel in arr:
      let tag = rel{"tag_name"}.getStr("")
      let name = rel{"name"}.getStr("")
      let link = rel{"_links"}{"self"}.getStr("")
      let pubDate = rel{"released_at"}.getStr(rel{"created_at"}.getStr(""))
      let title = if name.len > 0: name elif tag.len > 0: tag else: repo
      result.add Item(
        title: title, link: link,
        pubDate: rss.normalizePubDate(pubDate))
  except CatchableError:
    discard

# ---- Codeberg API ----
proc fetchCodebergApi(repo: string): seq[Item] =
  let url = "https://codeberg.org/api/v1/repos/" & repo & "/releases"
  let (code, body) = httpGet(url)
  if code != 200: return
  try:
    let arr = parseJson(body)
    for rel in arr:
      if rel{"prerelease"}.getBool(false) or rel{"draft"}.getBool(false): continue
      let tag = rel{"tag_name"}.getStr("")
      let name = rel{"name"}.getStr("")
      let link = rel{"html_url"}.getStr("")
      let pubDate = rel{"published_at"}.getStr("")
      let title = if name.len > 0: name elif tag.len > 0: tag else: repo
      result.add Item(
        title: title, link: link,
        pubDate: rss.normalizePubDate(pubDate))
  except CatchableError:
    discard

# ---- Atom fallback ----
proc fetchAtom(atomUrl: string): seq[Item] =
  let (code, body) = httpGet(atomUrl)
  if code != 200: return
  let fd = rss.parseRss(atomUrl, body)
  if fd.isOk:
    result = fd.data.items

proc fetchRepoRelease*(entry: string): seq[Item] =
  ## Fetch releases for one repo. Tries JSON API first, then Atom fallback.
  let rp = repoPath(entry)
  let prov = provider(entry)

  # 1. Try provider-specific JSON API.
  case prov
  of "gh":
    result = fetchGitHubApi(rp)
  of "gl":
    result = fetchGitLabApi(rp)
  of "cb":
    result = fetchCodebergApi(rp)
  else:
    result = fetchGitHubApi(rp)

  if result.len > 0: return

  # 2. Atom fallback.
  let atomUrl = case prov
    of "gh": "https://github.com/" & rp & "/releases.atom"
    of "gl": "https://gitlab.com/" & rp & "/-/releases.atom"
    of "cb": "https://codeberg.org/" & rp & "/releases.atom"
    else: "https://github.com/" & rp & "/releases.atom"
  result = fetchAtom(atomUrl)

proc fetchSoftwareReleases*(repos: seq[string]): FeedData =
  result = FeedData(
    title: "Software Updates",
    url: SwUrl,
    siteLink: "https://github.com")
  for repo in repos:
    if repo.len == 0: continue
    try:
      let items = fetchRepoRelease(repo)
      if items.len > 0:
        # Take only the LATEST release (first item, already sorted by date).
        var item = items[0]
        item.title = fixSoftwareTitle(item.title, repo)
        result.items.add(item)
    except CatchableError as e:
      echo "[sw-releases] ", repo, " failed: ", e.msg
  # Sort combined results by pub_date descending.
  result.items.sort do (a, b: Item) -> int:
    b.pubDate.cmp(a.pubDate)

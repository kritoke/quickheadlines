## YAML adapter - the single place that knows about NimYAML (design D4:
## every external lib behind a wrapper). Everything else in qh uses the domain
## `Config` type; only this module imports `yaml`.
##
## NimYAML limitation (recorded): it requires every declared field to be
## present in the YAML (Option[T] does NOT make a field optional). So the DTO
## declares only fields that are always present in feeds.yml; {.ignore: [].}
## drops the rest (per-feed header_color/item_limit, subreddit/sort, schedule_minutes,
## software_releases). Defaults for dropped fields are applied in toDomain.
## A config that omits a "required" field would fail; acceptable for P3.1
## (feeds.yml is canonical). Phase 3.x can revisit with DOM-based loading if
## full optionality is needed.

import std/[streams, os, options, strutils]
import yaml
import yaml/annotations
import ../results
import ../types

export yaml  # re-export so callers don't import yaml directly

type
  YamlFeed* {.ignore: [].} = object
    title*: string
    url*: string

  YamlSoftwareReleases* {.ignore: [].} = object
    title*: string
    repos*: seq[string]

  YamlClustering* {.ignore: [].} = object
    enabled*: bool
    run_on_startup*: bool
    threshold*: float

  YamlTab* {.ignore: [].} = object
    name*: string
    feeds*: seq[YamlFeed]
    # software_releases: not declared in DTO — NimYAML requires all declared
    # fields to be present, but not every tab has software_releases. Parsed
    # manually via parseSwRepos() below.

  YamlConfig* {.ignore: [].} = object
    debug*: bool
    refresh_minutes*: int
    page_title*: string
    item_limit*: int
    db_fetch_limit*: int
    server_port*: int
    cache_retention_hours*: int
    max_cache_size_mb*: int
    tabs*: seq[YamlTab]
    clustering*: YamlClustering

proc loadYamlConfig*(path: string): Result[YamlConfig, ConfigError] =
  ## Read + parse feeds.yml into the wire DTO. Missing file -> ceMissing;
  ## bad YAML -> ceMalformed. Defaults are applied in toDomain.
  if not fileExists(path): return err[YamlConfig, ConfigError](ceMissing)
  var y: YamlConfig
  try:
    let s = newFileStream(path, fmRead)
    defer: s.close()
    load(s, y)
    ok[YamlConfig, ConfigError](y)
  except CatchableError as e:
    discard e  # NimYAML raises YamlConstructionError / YamlParserError (e.msg)
    err[YamlConfig, ConfigError](ceMalformed)

# ---------------------------------------------------------------- mapping -> domain Config (defaults from Crystal src/config/structures.cr)

proc toDomain*(f: YamlFeed): Feed =
  Feed(title: f.title, url: f.url, headerColor: "", headerTextColor: "",
       itemLimit: 0)

proc toDomain*(c: YamlClustering): ClusteringConfig =
  ClusteringConfig(enabled: c.enabled, runOnStartup: c.run_on_startup,
                   maxItems: 0, maxFetchItems: 1000, threshold: c.threshold)

proc toDomain*(y: YamlConfig): Config =
  var tabs: seq[TabConfig]
  for t in y.tabs:
    var tfs: seq[Feed]
    for f in t.feeds: tfs.add f.toDomain()
    tabs.add TabConfig(name: t.name, feeds: tfs)
  Config(
    debug: y.debug, refreshMinutes: y.refresh_minutes, pageTitle: y.page_title,
    itemLimit: y.item_limit, dbFetchLimit: y.db_fetch_limit,
    serverPort: y.server_port, timelineBatchSize: 30,
    feeds: @[], tabs: tabs, clustering: y.clustering.toDomain())

proc parseSwRepos*(path: string): seq[string] =
  ## Parse software_release repos from the YAML config file. Extracts
  ## "- owner/repo:provider" lines under a "repos:" block that follows
  ## "software_releases:". Robust line-based parser (no NimYAML strictness).
  if not fileExists(path): return @[]
  let content = readFile(path)
  var inRepos = false
  for line in content.splitLines():
    let s = line.strip()
    if s == "software_releases:" or s.startsWith("software_releases:"):
      inRepos = true; continue
    if inRepos:
      if s.startsWith("repos:"): continue
      if s.startsWith("- "):
        # Strip quotes, then strip inline comments (# ...).
        var val = s[2..^1].strip(chars={'"', '\''})
        let commentIdx = val.find('#')
        if commentIdx >= 0: val = val[0 ..< commentIdx].strip()
        if val.len > 0 and '/' in val:
          result.add(val)
      elif s.len > 0 and not s.startsWith("#") and not s.startsWith("-") and not s.startsWith("title:"):
        inRepos = false  # left the repos block

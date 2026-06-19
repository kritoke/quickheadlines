## Production ConfigSource (design D4 boundary). Reads feeds.yml via the
## yaml_adapter (the only place that touches NimYAML), maps to the domain
## Config, validates feed URLs, and satisfies the ConfigSource concept.
##
## Port of Crystal src/config/loader.cr + validator.cr. No module-level state.

import std/[uri, strutils]
import ../types
import ./yaml_config

type
  YamlConfigSource* = ref object
    path*: string                 ## feeds.yml path (set at construction)

proc isValidFeedUrl(u: string): bool =
  ## Port of Crystal validator.cr: must be http(s) with a host.
  if u.len == 0: return false
  try:
    let p = parseUri(u)
    p.scheme in ["http", "https"] and p.hostname.len > 0
  except CatchableError:
    false

proc load*(src: YamlConfigSource): ConfigResult =
  ## Load feeds.yml -> validate -> domain Config. On error, returns the
  ## concrete ConfigResult (ceMissing / ceMalformed / ceInvalid).
  let yr = loadYamlConfig(src.path)
  if not yr.isOk: return errConfig(yr.err)
  let cfg = yr.val.toDomain()
  # Validate feed URLs (port of validator.cr).
  for f in cfg.feeds:
    if not isValidFeedUrl(f.url): return errConfig(ceInvalid)
  for t in cfg.tabs:
    for f in t.feeds:
      if not isValidFeedUrl(f.url): return errConfig(ceInvalid)
  okConfig(cfg)

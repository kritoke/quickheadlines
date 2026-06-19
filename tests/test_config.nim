## P3.1 config loader test - loads the real feeds.yml via the production
## YamlConfigSource, validates URLs, and proves the concept is satisfied.
## Run: nim c -r tests/test_config.nim

import std/[unittest, strutils]
import ../src/qh/types
import ../src/qh/concepts
import ../src/qh/config/yaml_config
import ../src/qh/config/config_source

static:
  doAssert YamlConfigSource is ConfigSource, "YamlConfigSource must satisfy ConfigSource"

suite "config loader (P3.1)":
  test "loads real feeds.yml":
    let src = YamlConfigSource(path: "feeds.yml")
    let r = src.load()
    check r.isOk
    if r.isOk:
      check r.config.pageTitle == "Quick Headlines"
      check r.config.refreshMinutes == 30
      check r.config.serverPort == 8080
      check r.config.debug == true
      check r.config.tabs.len > 0
      check r.config.tabs[0].name == "Tech"
      check r.config.tabs[0].feeds.len > 0
      check r.config.clustering.enabled == true
      check r.config.clustering.threshold == 0.35

  test "missing file -> ceMissing":
    let src = YamlConfigSource(path: "does_not_exist.yml")
    let r = src.load()
    check not r.isOk
    check r.err == ceMissing

  test "all feed URLs are valid http(s)":
    let src = YamlConfigSource(path: "feeds.yml")
    let r = src.load()
    check r.isOk
    for t in r.config.tabs:
      for f in t.feeds:
        check f.url.startsWith("http")

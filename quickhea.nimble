# Nimble package metadata for the QuickHeadlines Nim port.
# Phase-1 spike: stdlib-only (zero external deps) to validate feasibility.
# Backend code lives under src/qh/. The carried-over Crystal src/*.cr is kept
# as reference only on this branch (not compiled here).
version       = "0.1.0"
author        = "QuickHeadlines"
description   = "QuickHeadlines backend - Nim port (Phase-1 spike)"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"

bin = @["qh/spike/fetch_vertical", "qh/spike/clustering_vertical", "qh/main"]

# Dependencies: Phase-3 build-out adds wrapped deps (design D4: every external
# lib behind an adapter). Phase-1/2 were zero-dep.
requires "nim >= 2.2.0"
requires "yaml >= 2.2.0"
requires "tiny_sqlite >= 0.1.0"
requires "fusion >= 1.2.0"
requires "stb_image >= 2.5.0"   # image decode for color extraction (prismatiq port)

task test, "Run all Phase-2/3 tests":
  exec "nim c -d:ssl --threads:on -r tests/test_concept_checks.nim"
  exec "nim c -d:ssl --threads:on -r tests/test_config.nim"
  exec "nim c -d:ssl --threads:on -r tests/test_storage.nim"
  exec "nim c -d:ssl --threads:on -r tests/test_sqlite_stores.nim"
  exec "nim c -d:ssl --threads:on -r tests/test_fetcher.nim"
  exec "nim c -d:ssl --threads:on -r tests/test_clustering.nim"


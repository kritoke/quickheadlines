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

bin = @["qh/spike/fetch_vertical", "qh/spike/clustering_vertical"]

# Dependencies: Phase-3 build-out adds wrapped deps (design D4: every external
# lib behind an adapter). Phase-1/2 were zero-dep.
requires "nim >= 2.2.0"
requires "yaml >= 2.2.0"

task test, "Run the Phase-2/3 contract + in-memory + config tests":
  exec "nim c -r tests/test_concept_checks.nim"
  exec "nim c -r tests/test_config.nim"


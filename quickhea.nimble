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

# Dependencies: deliberately none for the spike. Phase-3 build-out may add
# a SQLite binding, an HTTP server framework, etc. (each behind a wrapper,
# per design D4).
requires "nim >= 2.2.0"

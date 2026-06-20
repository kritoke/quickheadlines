## Compile-time asset embedding - Nim's equivalent of Crystal's baked_file_system
## (design D8). At compile time, every file under frontend/dist is read into a
## Table keyed by its URL path, with a content-type. In production the binary is
## self-contained; in dev, build frontend/ first (`cd frontend && npm run build`)
## then compile main.nim so the embed picks up fresh assets.
##
## Note: Nim's staticExec/staticRead run with CWD = this source file's dir, so
## paths are made absolute from currentSourcePath.

import std/[options, tables, strutils, os]

# src/qh/web/assets.nim -> 4 parents up = project root.
const Root* = currentSourcePath.parentDir.parentDir.parentDir.parentDir
const DistDir* = Root & "/frontend/dist"

const FileList = staticExec("find " & DistDir & " -type f").strip().split('\n')

proc contentType(path: string): string =
  let ext = path.rsplit('.', maxsplit = 1)
  case if ext.len == 2: ext[1] else: ""
  of "html": "text/html; charset=utf-8"
  of "css":  "text/css; charset=utf-8"
  of "js":   "application/javascript; charset=utf-8"
  of "json": "application/json; charset=utf-8"
  of "svg":  "image/svg+xml"
  of "png":  "image/png"
  of "ico":  "image/x-icon"
  of "woff", "woff2": "font/" & (if ext.len == 2: ext[1] else: "woff")
  else: "application/octet-stream"

type Asset* = tuple[content: string; contentType: string]

proc urlPathOf(f: string): string =
  ## absolute dist file path -> "/_app/.../x.js"
  f[DistDir.len..^1]

proc initAssets(): Table[string, Asset] =
  for f in FileList:
    if f.len == 0: continue
    let a: Asset = (staticRead(f), contentType(f))
    result[urlPathOf(f)] = a

const Assets = initAssets()
const IndexAsset: Asset = (staticRead(DistDir & "/index.html"), "text/html; charset=utf-8")

proc getAsset*(path: string): Option[Asset] =
  ## Exact-match lookup by URL path. none if not an embedded file.
  if path in Assets: some(Assets[path]) else: none(Asset)

proc indexAsset*(): Asset = IndexAsset

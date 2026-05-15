# Build: 2026-05-14T20:57:46-05:00
# This comment is updated before each build to force BakedFileSystem recompilation
# DO NOT remove this line - it's used by the build system

require "baked_file_system"

class FrontendAssets
  extend BakedFileSystem

  # bake_folder requires a string literal path
  # Use dir: "." to make path relative to where crystal is invoked (project root), not this file's directory
  bake_folder "frontend/dist", dir: "."
end
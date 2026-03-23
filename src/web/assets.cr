# Build: 2026-03-22T19:10:30-05:00
# This comment is updated before each build to force BakedFileSystem recompilation
# DO NOT remove this line - it's used by the build system

require "baked_file_system"

class FrontendAssets
  extend BakedFileSystem

  bake_folder "../../frontend/dist", max_size: 50_000_000
end

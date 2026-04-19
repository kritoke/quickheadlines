# Build: 2026-04-19T11:15:13-05:00
# This comment is updated before each build to force BakedFileSystem recompilation
# DO NOT remove this line - it's used by the build system

require "baked_file_system"

class FrontendAssets
  extend BakedFileSystem

  bake_folder "../../frontend/dist", max_size: 50_000_000
end

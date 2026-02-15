# Build: 2026-02-14T22:09:11-06:00
# This comment is updated before each build to force BakedFileSystem recompilation
# DO NOT remove this line - it's used by the build system

require "baked_file_system"

class FrontendAssets
  extend BakedFileSystem
  
  bake_folder "../../frontend/dist"
end

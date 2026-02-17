<<<<<<< HEAD
<<<<<<< HEAD
# Build: 2026-02-17T07:56:50-06:00
=======
# Build: 2026-02-17T06:44:25-06:00
>>>>>>> 22b6938 (Remove deprecated root package.json and package-lock.json)
=======
# Build: 2026-02-17T07:56:50-06:00
>>>>>>> aebe4cc (Update default cache settings: retention to 336h (14 days), document all config options)
# This comment is updated before each build to force BakedFileSystem recompilation
# DO NOT remove this line - it's used by the build system

require "baked_file_system"

class FrontendAssets
  extend BakedFileSystem

  bake_folder "../../frontend/dist"
end

require "baked_file_system"

class FrontendAssets
  extend BakedFileSystem
  
  bake_folder "../../frontend/dist"
end

# Build: 2026-05-12T05:04:41-05:00
# This comment is updated before each build to force BakedFileSystem recompilation
# DO NOT remove this line - it's used by the build system

require "baked_file_system"

class FrontendAssets
  extend BakedFileSystem

  # Relative path to frontend dist - bake_folder requires string literal
  bake_folder "#{__DIR__}/../../frontend/dist", max_size: 50_000_000
end

# Validate at runtime that frontend dist exists (called from application startup)
def self.validate_frontend_dist : Nil
  dist_path = File.join(__DIR__, "..", "..", "frontend", "dist")
  unless Dir.exists?(dist_path)
    raise "ERROR: frontend/dist not found at #{dist_path}. Run 'cd frontend && npm run build' before starting the server."
  end
end

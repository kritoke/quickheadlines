require "http"

class StaticAssetHandler
  include HTTP::Handler

  def call(context : HTTP::Server::Context)
    path = context.request.path
    
    if path.starts_with?("/_app/")
      asset_path = path[1..]
      
      if ENV["APP_ENV"]? == "development"
        file_path = "./frontend/dist/#{asset_path}"
        if File.exists?(file_path)
          serve_file(context, file_path, asset_path)
          return
        end
      end
      
      begin
        file = FrontendAssets.get(asset_path)
        content = file.gets_to_end
        send_response(context, content, asset_path)
        return
      rescue BakedFileSystem::NoSuchFileError
        context.response.status = :not_found
        context.response.content_type = "text/plain"
        context.response << "Not Found: #{asset_path}"
        return
      rescue ex
        context.response.status = :internal_server_error
        context.response.content_type = "text/plain"
        context.response << "Error: #{ex.message}"
        return
      end
    end
    
    call_next(context)
  end

  private def serve_file(context : HTTP::Server::Context, file_path : String, asset_path : String)
    begin
      content = File.read(file_path)
      send_response(context, content, asset_path)
    rescue ex
      context.response.status = :internal_server_error
      context.response.content_type = "text/plain"
      context.response << "Error: #{ex.message}"
    end
  end

  private def send_response(context : HTTP::Server::Context, content : String, asset_path : String)
    ext = asset_path.split(".").last?.try(&.downcase) || ""
    mime = case ext
           when "js"   then "application/javascript; charset=utf-8"
           when "css"  then "text/css; charset=utf-8"
           when "json" then "application/json"
           when "svg"  then "image/svg+xml"
           when "png"  then "image/png"
           when "woff", "woff2" then "font/woff2"
           else "application/octet-stream"
           end
    
    context.response.content_type = mime
    context.response << content
    
    if asset_path.includes?("/immutable/")
      context.response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
    else
      context.response.headers["Cache-Control"] = "public, max-age=3600"
    end
  end
end

require "http/client"

# ElmJs manages serving the compiled Elm JavaScript file from disk
# or downloading from GitHub as a fallback in production.
module ElmJs
  ELM_JS_PATH    = "public/elm.js"
  GITHUB_RAW_URL = "https://raw.githubusercontent.com/kritoke/quickheadlines/main/public/elm.js"

  # Check if elm.js file exists on disk
  def self.exists? : Bool
    File.exists?(ELM_JS_PATH)
  end

  # Get file size in bytes
  def self.size : Int64
    if exists?
      File.size(ELM_JS_PATH).to_i64
    else
      0_i64
    end
  end

  # Get file modification time
  def self.mtime : Time?
    if exists?
      File.info(ELM_JS_PATH).modification_time
    end
  end

  # Serve elm.js from disk or download from GitHub
  def self.serve(context : HTTP::Server::Context) : Nil
    # In development, always require file on disk
    {% if env("APP_ENV") == "development" %}
      unless exists?
        context.response.status_code = 404
        context.response.content_type = "text/plain; charset=utf-8"
        context.response.print "elm.js not found - run 'make elm-build' first"
        return
      end

      context.response.content_type = "application/javascript; charset=utf-8"
      context.response.headers["Cache-Control"] = "public, max-age=31536000"
      File.open(ELM_JS_PATH) do |file|
        IO.copy(file, context.response)
      end
    {% else %}
      # In production, serve from disk if available, otherwise download from GitHub
      if exists?
        context.response.content_type = "application/javascript; charset=utf-8"
        context.response.headers["Cache-Control"] = "public, max-age=31536000"
        File.open(ELM_JS_PATH) do |file|
          IO.copy(file, context.response)
        end
      else
        # Fallback to downloading from GitHub in production
        download_and_serve(context)
      end
    {% end %}
  end

  # Download elm.js from GitHub and serve it
  private def self.download_and_serve(context : HTTP::Server::Context) : Nil
    puts "[ElmJs] Downloading elm.js from GitHub..."

    HTTP::Client.get(GITHUB_RAW_URL) do |response|
      if response.status_code == 200
        # Save to disk for future requests
        content = response.body_io.gets_to_end
        File.write(ELM_JS_PATH, content)

        # Serve the downloaded file
        context.response.content_type = "application/javascript; charset=utf-8"
        context.response.headers["Cache-Control"] = "public, max-age=31536000"
        context.response.print content

        puts "[ElmJs] Successfully downloaded and cached elm.js"
      else
        context.response.status_code = 502
        context.response.content_type = "text/plain; charset=utf-8"
        context.response.print "Failed to download elm.js from GitHub (status: #{response.status_code})"
        puts "[ElmJs] Failed to download elm.js from GitHub (status: #{response.status_code})"
      end
    end
  rescue ex : Exception
    context.response.status_code = 502
    context.response.content_type = "text/plain; charset=utf-8"
    context.response.print "Failed to download elm.js from GitHub: #{ex.message}"
    puts "[ElmJs] Error downloading elm.js from GitHub: #{ex.message}"
  end
end

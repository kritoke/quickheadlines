require "./application"

begin
  config_result = load_config_with_validation("feeds.yml")
  port = 8080

  if config_result.success
    cfg = config_result.config.as(Config)
    port = cfg.server_port
  else
    STDERR.puts "[WARN] Could not load feeds.yml to determine server_port; defaulting to #{port}"
  end

  static_handler = StaticAssetHandler.new
  STDERR.puts "[DEBUG] Created StaticAssetHandler: #{static_handler.class}"
  
  ATH.run(port: port, prepend_handlers: [static_handler])
rescue ex
  STDERR.puts "[ERROR] Failed to start server: #{ex.message}"
  STDERR.puts ex.backtrace.join("\n")
  exit 1
end

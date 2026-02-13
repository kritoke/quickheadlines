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

  ATH.run(port: port)
rescue ex
  STDERR.puts "[ERROR] Failed to start server: #{ex.message}"
  exit 1
end

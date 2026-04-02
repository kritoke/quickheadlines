require "time"

module HealthMonitor
  def self.log_error(context : String, exception : Exception)
    Log.for("quickheadlines.health").error(exception: exception) { "ERROR in #{context}: #{exception.class}" }
  end

  def self.log_error(context : String, error_message : String)
    Log.for("quickheadlines.health").error { "ERROR in #{context}: #{error_message}" }
  end

  def self.log_warning(message : String)
    Log.for("quickheadlines.health").warn { "WARNING: #{message}" }
  end

  def self.log_info(message : String)
    Log.for("quickheadlines.health").info { "INFO: #{message}" }
  end
end

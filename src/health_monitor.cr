require "time"

module HealthMonitor
  def self.log_error(context : String, exception : Exception)
    STDERR.puts "[#{Time.local}] ERROR in #{context}: #{exception.class} - #{exception.message}"
    STDERR.puts exception.backtrace.first(10).join("\n")
  end

  def self.log_error(context : String, error_message : String)
    STDERR.puts "[#{Time.local}] ERROR in #{context}: #{error_message}"
  end

  def self.log_warning(message : String)
    STDERR.puts "[#{Time.local}] WARNING: #{message}"
  end

  def self.log_info(message : String)
    STDERR.puts "[#{Time.local}] INFO: #{message}"
  end
end

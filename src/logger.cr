require "json"

module AppLogger
  enum Level
    DEBUG
    INFO
    WARN
    ERROR
  end

  class Configuration
    property level : Level
    property output : IO

    def initialize(@level = Level::INFO, @output = STDERR)
    end
  end

  @@config = Configuration.new

  def self.config : Configuration
    @@config
  end

  def self.configure(& : Configuration ->)
    yield @@config
  end

  def self.level : Level
    @@config.level
  end

  def self.output : IO
    @@config.output
  end

  def self.debug? : Bool
    level <= @@config.level
  end

  def self.info? : Bool
    level <= @@config.level
  end

  def self.warn? : Bool
    level <= @@config.level
  end

  def self.error? : Bool
    level <= @@config.level
  end

  def self.debug(message : String, context : Hash(String, String)? = nil) : Nil
    log(Level::DEBUG, message, context)
  end

  def self.info(message : String, context : Hash(String, String)? = nil) : Nil
    log(Level::INFO, message, context)
  end

  def self.warn(message : String, context : Hash(String, String)? = nil) : Nil
    log(Level::WARN, message, context)
  end

  def self.error(message : String, context : Hash(String, String)? = nil) : Nil
    log(Level::ERROR, message, context)
  end

  def self.error(ex : Exception, context : Hash(String, String)? = nil) : Nil
    error_msg = "#{ex.class}: #{ex.message}"
    error(error_msg, context)
  end

  private def self.log(level : Level, message : String, context : Hash(String, String)?) : Nil
    return if level < @@config.level

    timestamp = Time.local.to_s("%Y-%m-%d %H:%M:%S")
    level_str = level.to_s.ljust(5)

    output = @@config.output
    output.print "[#{timestamp}] [#{level_str}] #{message}"

    if context && !context.empty?
      output.print " #{context.to_json}"
    end

    output.puts
    output.flush
  end
end

alias Logger = AppLogger

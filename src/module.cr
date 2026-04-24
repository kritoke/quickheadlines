require "./config"
require "./services/app_bootstrap"

module QuickHeadlines
  @@initial_config : Config?
  @@bootstrap : AppBootstrap?
  @@shutting_down = Atomic(Bool).new(false)

  def self.initial_config : Config?
    @@initial_config
  end

  def self.initial_config=(value : Config?)
    @@initial_config = value
  end

  def self.bootstrap : AppBootstrap?
    @@bootstrap
  end

  def self.bootstrap=(value : AppBootstrap?)
    @@bootstrap = value
  end

  def self.shutting_down? : Bool
    @@shutting_down.get
  end

  def self.shutting_down=(value : Bool)
    @@shutting_down.set(value)
  end
end

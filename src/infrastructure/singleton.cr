# Macro to reduce singleton boilerplate.
#
# Two variants:
#   def_singleton_auto   — auto-initializes via ClassName.new.tap(&.start)
#   def_singleton_manual — raises if not set, requires explicit `instance=` call
#
# Usage:
#   class MyActor < Actor
#     def_singleton_auto
#   end
#
#   class MyService
#     def_singleton_manual("MyService: Not initialized")
#   end
#

macro def_singleton_auto
  @@instance : {{@type.id}}?
  @@instance_mutex = Mutex.new

  def self.instance : {{@type.id}}
    @@instance_mutex.synchronize do
      @@instance ||= {{@type.id}}.new.tap(&.start)
    end
  end

  def self.reset : Nil
    @@instance_mutex.synchronize do
      if inst = @@instance
        inst.shutdown rescue nil
      end
      @@instance = nil
    end
  end
end

macro def_singleton_manual(error_message = "Not initialized")
  @@instance : {{@type.id}}?
  @@instance_mutex = Mutex.new

  def self.instance : {{@type.id}}
    @@instance_mutex.synchronize do
      @@instance || raise {{error_message}}
    end
  end

  def self.instance=(value : {{@type.id}})
    @@instance_mutex.synchronize { @@instance = value }
  end
end

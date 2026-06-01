require "channel"
require "log"

# ============================================================================
# Actor Model Framework for Crystal
# ============================================================================
#
# Macro-driven, fault-isolated actor model using Channels and Fibers.
# No external dependencies — pure Crystal core features.
#
# ## Usage
#
#   class CounterActor < Actor
#     def_cast increment(amount : Int32)
#     def_cast reset
#     def_call get_count : Int32
#
#     def initialize(@name : String = "Counter")
#       super(@name)
#       @count = 0
#     end
#
#     private def handle_increment(amount : Int32) : Nil
#       @count += amount
#     end
#
#     private def handle_reset : Nil
#       @count = 0
#     end
#
#     private def handle_get_count : Int32
#       @count
#     end
#   end
#
#   actor = CounterActor.new
#   actor.start
#   actor.increment(5)
#   count = actor.get_count
#   actor.stop
#

# Default timeout for def_call request-reply to prevent callers from hanging
# forever if the actor is deadlocked, crashed, or the mailbox is full.
ACTOR_CALL_TIMEOUT_SECONDS = 30_i64

abstract class Actor
  abstract struct Message
  end

  abstract struct CastMessage < Message
    abstract def deliver_reply : Nil
  end

  abstract struct CallMessage(R) < Message
    abstract def deliver_reply(value : R) : Nil
    abstract def deliver_error(message : String) : Nil
  end

  @mailbox : Channel(Message)
  @running : Bool = false
  @messages_processed : Atomic(Int64) = Atomic(Int64).new(0)
  @messages_failed : Atomic(Int64) = Atomic(Int64).new(0)

  property name : String

  def initialize(@name : String = self.class.name, mailbox_size : Int32 = 100)
    @mailbox = Channel(Message).new(mailbox_size)
  end

  def start : Nil
    return if @running
    @running = true
    spawn(name: "actor-#{@name}") { run_loop }
  end

  # Graceful shutdown: stops accepting new messages, waits for in-flight work to
  # complete, then exits the message loop cleanly.
  #
  # Actors that do blocking work (HTTP I/O, LSH computation) should override
  # `graceful_shutdown_timeout` to allow enough time for cleanup.
  def shutdown : Nil
    @running = false
    @mailbox.close rescue Channel::ClosedError
  end

  protected def send_message(message : Message) : Nil
    @mailbox.send(message)
  end

  private def run_loop : Nil
    Log.for("actor.#{@name}").debug { "Started" }

    while @running
      begin
        message = @mailbox.receive?
        break if message.nil?

        begin
          dispatch(message)
          @messages_processed.add(1)
        rescue ex
          @messages_failed.add(1)
          Log.for("actor.#{@name}").error(exception: ex) { "Error processing #{message.class.name}" }
        end
      rescue Channel::ClosedError
        break
      rescue ex
        Log.for("actor.#{@name}").error(exception: ex) { "Fatal actor loop error" }
        break
      end
    end

    Log.for("actor.#{@name}").debug { "Stopped (processed=#{@messages_processed.get}, failed=#{@messages_failed.get})" }
  end

  # Subclasses can override this to allow more time for graceful shutdown
  # (e.g., FaviconActor or ClusteringActor that do blocking work).
  # Returns the timeout in seconds before the actor is force-killed.
  protected def graceful_shutdown_timeout : Int64
    5_i64
  end

  abstract def dispatch(message : Message)

  protected def _actor_call_with_timeout(reply_ch : Channel(T), timeout_seconds : Int64) : T forall T
    select
    when value = reply_ch.receive
      value
    when timeout(timeout_seconds.seconds)
      raise CallTimeoutError.new("Actor call timed out after #{timeout_seconds}s")
    end
  rescue Channel::ClosedError
    raise CallTimeoutError.new("Actor call failed: mailbox closed")
  end

  def stats : {processed: Int64, failed: Int64, running: Bool}
    {processed: @messages_processed.get, failed: @messages_failed.get, running: @running}
  end
end

# ============================================================================
# def_cast — fire-and-forget message (tell semantics)
# ============================================================================
#
# Two forms:
#   def_cast reset                            # no-arg (TypeDeclaration)
#   def_cast increment(amount : Int32)        # with-args (Call)
#
# Subclass must implement: private def handle_NAME(args...) : Nil
#
macro def_cast(call)
  {% if call.is_a?(TypeDeclaration) %}
    # No-arg form: def_cast reset
    {% method_name = call.var.stringify %}
    {% struct_name = ("Cast" + method_name.camelcase).id %}

    struct {{struct_name}} < CastMessage
      def initialize
      end

      def deliver_reply : Nil
      end
    end

    def {{method_name.id}} : Nil
      send_message({{struct_name}}.new)
    end
  {% else %}
    # With-args form: def_cast increment(amount : Int32)
    {% method_name = call.name.stringify %}
    {% struct_name = ("Cast" + method_name.camelcase).id %}
    {% args = call.args %}

    struct {{struct_name}} < CastMessage
      {% for arg in args %}
        @{{arg.var.id}} : {{arg.type}}
      {% end %}

      def initialize({% for arg, i in args %}{{arg.var.id}} : {{arg.type}}{% if i < args.size - 1 %}, {% end %}{% end %})
        {% for arg in args %}
          @{{arg.var.id}} = {{arg.var.id}}
        {% end %}
      end

      {% for arg in args %}
        def {{arg.var.id}}
          @{{arg.var.id}}
        end
      {% end %}

      def deliver_reply : Nil
      end
    end

    def {{method_name.id}}({% for arg, i in args %}{{arg.var.id}} : {{arg.type}}{% if i < args.size - 1 %}, {% end %}{% end %}) : Nil
      send_message({{struct_name}}.new({% for arg, i in args %}{{arg.var.id}}{% if i < args.size - 1 %}, {% end %}{% end %}))
    end
  {% end %}
end

# ============================================================================
# def_call — synchronous request-reply (ask semantics)
# ============================================================================
#
# Two forms:
#   def_call get_count : Int32                            # no-arg (TypeDeclaration)
#   def_call register(ws : WebSocket, ip : String), Bool  # with-args (Call, ReturnType)
#
# With-args form passes return type as second macro argument because
# Crystal parses `method(args) : Type` as a return type annotation on the
# call, which is not valid syntax for macro arguments.
#
# Subclass must implement: private def handle_NAME(args...) : ReturnType
#
macro def_call(call, return_type = nil)
  {% if call.is_a?(TypeDeclaration) %}
    # No-arg form: def_call get_count : Int32
    {% method_name = call.var.stringify %}
    {% return_type = call.type %}
    {% struct_name = ("Call" + method_name.camelcase).id %}

    struct {{struct_name}} < CallMessage({{return_type}})
      @reply : Channel({{return_type}})

      def initialize(@reply : Channel({{return_type}}))
      end

      def reply : Channel({{return_type}})
        @reply
      end

      def deliver_reply(value : {{return_type}}) : Nil
        @reply.send(value)
      rescue Channel::ClosedError
      end

      def deliver_error(message : String) : Nil
        # No-op: caller already received CallTimeoutError from _actor_call_with_timeout.
        # This exists only to satisfy the CallMessage interface.
      end
    end

    def {{method_name.id}} : {{return_type}}
      reply_ch = Channel({{return_type}}).new(1)
      send_message({{struct_name}}.new(reply_ch))
      _actor_call_with_timeout(reply_ch, ACTOR_CALL_TIMEOUT_SECONDS)
    end
  {% else %}
    # With-args form: def_call register(ws : WebSocket, ip : String), Bool
    {% method_name = call.name.stringify %}
    {% args = call.args %}
    {% struct_name = ("Call" + method_name.camelcase).id %}

    struct {{struct_name}} < CallMessage({{return_type}})
      {% for arg in args %}
        @{{arg.var.id}} : {{arg.type}}
      {% end %}
      @reply : Channel({{return_type}})

      def initialize({% for arg, i in args %}{{arg.var.id}} : {{arg.type}}, {% end %}@reply : Channel({{return_type}}))
        {% for arg in args %}
          @{{arg.var.id}} = {{arg.var.id}}
        {% end %}
      end

      {% for arg in args %}
        def {{arg.var.id}}
          @{{arg.var.id}}
        end
      {% end %}

      def reply : Channel({{return_type}})
        @reply
      end

      def deliver_reply(value : {{return_type}}) : Nil
        @reply.send(value)
      rescue Channel::ClosedError
      end

      def deliver_error(message : String) : Nil
        # No-op: caller already received CallTimeoutError from _actor_call_with_timeout.
        # This exists only to satisfy the CallMessage interface.
      end
    end

    def {{method_name.id}}({% for arg, i in args %}{{arg.var.id}} : {{arg.type}}{% if i < args.size - 1 %}, {% end %}{% end %}) : {{return_type}}
      reply_ch = Channel({{return_type}}).new(1)
      send_message({{struct_name}}.new({% for arg, i in args %}{{arg.var.id}}, {% end %}reply_ch))
      _actor_call_with_timeout(reply_ch, ACTOR_CALL_TIMEOUT_SECONDS)
    end
  {% end %}
end

# Raised when a def_call message does not receive a reply within the timeout.
# Indicates the actor is stuck, crashed, or the mailbox is saturated.
class CallTimeoutError < Exception
end

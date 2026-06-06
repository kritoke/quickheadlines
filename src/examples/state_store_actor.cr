require "../infrastructure/actor"

# Example: StateStore Actor
#
# Demonstrates def_cast (fire-and-forget) and def_call (request-reply).
# All state mutations serialized through actor mailbox — no mutexes needed.
#
class StateStoreActor < Actor
  # === Fire-and-forget messages ===
  def_cast set_title(title : String)
  def_cast set_refreshing(val : Bool)
  def_cast set_clustering(val : Bool)
  def_cast increment_counter

  # === Synchronous request-reply messages ===
  def_call get_title : String
  def_call is_refreshing : Bool
  def_call is_clustering : Bool
  def_call get_counter : Int32

  def initialize(@name : String = "StateStore")
    super(@name)
    @title = "Quick Headlines"
    @refreshing = false
    @clustering = false
    @counter = 0
  end

  # Message dispatch — routes messages to handlers
  def dispatch(message : Message) : Nil
    case message
    when CastSetTitle         then handle_set_title(message.title)
    when CastSetRefreshing    then handle_set_refreshing(message.val)
    when CastSetClustering    then handle_set_clustering(message.val)
    when CastIncrementCounter then handle_increment_counter
    when CallGetTitle         then message.deliver_reply_json(handle_get_title.to_json)
    when CallIsRefreshing     then message.deliver_reply_json(handle_is_refreshing.to_json)
    when CallIsClustering     then message.deliver_reply_json(handle_is_clustering.to_json)
    when CallGetCounter       then message.deliver_reply_json(handle_get_counter.to_json)
    else                           raise "Unknown message: #{message.class.name}"
    end
  end

  # === Cast handlers ===

  private def handle_set_title(title : String) : Nil
    @title = title
  end

  private def handle_set_refreshing(val : Bool) : Nil
    @refreshing = val
  end

  private def handle_set_clustering(val : Bool) : Nil
    @clustering = val
  end

  private def handle_increment_counter : Nil
    @counter += 1
  end

  # === Call handlers ===

  private def handle_get_title : String
    @title
  end

  private def handle_is_refreshing : Bool
    @refreshing
  end

  private def handle_is_clustering : Bool
    @clustering
  end

  private def handle_get_counter : Int32
    @counter
  end
end

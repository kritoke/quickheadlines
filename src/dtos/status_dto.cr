require "athena"

@[ASRA::Name(strategy: :camelcase)]
class QuickHeadlines::DTOs::StatusResponse
  include ASR::Serializable

  property? clustering : Bool
  property? refreshing : Bool
  property active_jobs : Int32
  property websocket_connections : Int32
  property websocket_messages_sent : Int64
  property websocket_messages_dropped : Int64
  property websocket_send_errors : Int64
  property broadcaster_processed : Int64
  property broadcaster_dropped : Int64

  def initialize(
    @clustering : Bool,
    @refreshing : Bool,
    @active_jobs : Int32,
    @websocket_connections : Int32 = 0,
    @websocket_messages_sent : Int64 = 0,
    @websocket_messages_dropped : Int64 = 0,
    @websocket_send_errors : Int64 = 0,
    @broadcaster_processed : Int64 = 0,
    @broadcaster_dropped : Int64 = 0,
  )
  end
end

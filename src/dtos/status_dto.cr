require "athena"

@[ASRA::Name(strategy: :camelcase)]
class Quickheadlines::DTOs::StatusResponse
  include ASR::Serializable

  property? clustering : Bool
  property? refreshing : Bool
  property active_jobs : Int32

  def initialize(@clustering : Bool, @refreshing : Bool, @active_jobs : Int32)
  end
end

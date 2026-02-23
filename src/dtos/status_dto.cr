require "athena"

@[ASRA::Name(strategy: :camelcase)]
class Quickheadlines::DTOs::StatusResponse
  include ASR::Serializable

  property? is_clustering : Bool
  property? is_refreshing : Bool
  property active_jobs : Int32

  def initialize(@is_clustering : Bool, @is_refreshing : Bool, @active_jobs : Int32)
  end
end

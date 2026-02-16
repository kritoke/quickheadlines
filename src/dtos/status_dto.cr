require "athena"

@[ASRA::Name(strategy: :camelcase)]
class Quickheadlines::DTOs::StatusResponse
  include ASR::Serializable

  property? is_clustering : Bool
  property active_jobs : Int32

  def initialize(@is_clustering : Bool, @active_jobs : Int32)
  end
end

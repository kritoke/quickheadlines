require "athena"

@[ASRA::Name(strategy: :camelcase)]
class Quickheadlines::DTOs::RateLimitStatsResponse
  include ASR::Serializable

  property total_entries : Int32
  property by_category : Hash(String, Int32)

  def initialize(@total_entries : Int32, @by_category : Hash(String, Int32))
  end
end

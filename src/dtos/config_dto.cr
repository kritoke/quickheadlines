require "athena"

@[ASRA::Name(strategy: :camelcase)]
class Quickheadlines::DTOs::ConfigResponse
  include ASR::Serializable

  property refresh_minutes : Int32
  property item_limit : Int32

  def initialize(@refresh_minutes : Int32, @item_limit : Int32)
  end
end

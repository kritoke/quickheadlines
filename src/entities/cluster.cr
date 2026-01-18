require "athena"

module Quickheadlines::Entities
  class Cluster
    property id : String
    property representative : Story
    property others : Array(Story)
    property size : Int32

    def initialize(
      @id : String,
      @representative : Story,
      @others : Array(Story) = [] of Story,
      @size : Int32 = 1
    )
      @size = 1 + others.size
    end
  end
end

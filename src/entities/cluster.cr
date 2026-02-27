require "athena"

module Quickheadlines::Entities
  struct Cluster
    getter id : String
    getter representative : Story
    getter others : Array(Story)
    getter size : Int32

    def initialize(
      @id : String,
      @representative : Story,
      @others : Array(Story) = [] of Story,
      size : Int32? = nil
    )
      @size = size || 1 + @others.size
    end

    def copy_with(
      id : String? = nil,
      representative : Story? = nil,
      others : Array(Story)? = nil,
      size : Int32? = nil
    ) : Cluster
      Cluster.new(
        id || @id,
        representative || @representative,
        others || @others,
        size || @size
      )
    end
  end
end

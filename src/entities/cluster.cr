require "athena"

module QuickHeadlines::Entities
  record Cluster,
    id : String,
    representative : Story,
    others : Array(Story) = [] of Story do
    def size : Int32
      1 + others.size
    end
  end
end

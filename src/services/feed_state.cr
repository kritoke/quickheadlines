module QuickHeadlines::Services
  abstract struct FeedState
  end

  struct FeedState::Idle < FeedState
    getter feeds : Array(FeedData)
    getter tabs : Array(Tab)
    getter updated_at : Time?

    def initialize(@feeds = [] of FeedData, @tabs = [] of Tab, @updated_at = nil)
    end
  end

  struct FeedState::Loading < FeedState
    getter previous_feeds : Array(FeedData)?
    getter previous_tabs : Array(Tab)?

    def initialize(@previous_feeds = nil, @previous_tabs = nil)
    end
  end

  struct FeedState::Refreshing < FeedState
    getter current_feeds : Array(FeedData)
    getter current_tabs : Array(Tab)

    def initialize(@current_feeds, @current_tabs)
    end
  end

  struct FeedState::Error < FeedState
    getter message : String
    getter stale_feeds : Array(FeedData)?
    getter stale_tabs : Array(Tab)?

    def initialize(@message, @stale_feeds = nil, @stale_tabs = nil)
    end
  end
end

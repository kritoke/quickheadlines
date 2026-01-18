require "athena"

class Quickheadlines::Repositories::FeedRepository
  def find_all : Array(Quickheadlines::Entities::Feed)
    # TODO: Implement find all feeds
    [] of Quickheadlines::Entities::Feed
  end

  def find(id : String) : Quickheadlines::Entities::Feed?
    # TODO: Implement find feed by id
    nil
  end

  def find_stories(feed_id : String) : Array(Quickheadlines::Entities::Story)
    # TODO: Implement find stories by feed id
    [] of Quickheadlines::Entities::Story
  end

  def save(feed : Quickheadlines::Entities::Feed) : Quickheadlines::Entities::Feed
    # TODO: Implement save feed
    feed
  end
end

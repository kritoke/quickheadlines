enum RepositoryError
  NotFound
  DatabaseError
  InvalidData
end

alias FeedResult = Result(Quickheadlines::Entities::Feed, RepositoryError)
alias FeedDataResult = Result(FeedData, RepositoryError)
alias TimeResult = Result(Time, RepositoryError)

# Fetcher result types
alias FetchResult = Result(FeedData, String)
alias SoftwareFetchResult = Result(FeedData, String)
alias RedditFetchResult = Result(FeedData, String)

class FeedFetchError < Exception
  getter feed_url : String

  def initialize(message : String, @feed_url : String)
    super(message)
  end
end

class ConfigurationError < Exception
end

class DatabaseError < Exception
  getter original_error : Exception?

  def initialize(message : String, @original_error : Exception? = nil)
    super(message)
  end
end

class RateLimitError < Exception
  getter retry_after : Int32?

  def initialize(message : String, @retry_after : Int32? = nil)
    super(message)
  end
end

class ProxyForbiddenError < Exception
  getter blocked_domain : String

  def initialize(message : String, @blocked_domain : String)
    super(message)
  end
end

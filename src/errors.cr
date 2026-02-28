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

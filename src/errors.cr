enum RepositoryError
  NotFound
  DatabaseError
  InvalidData
end

alias FeedResult = Result(Quickheadlines::Entities::Feed, RepositoryError)
alias FeedDataResult = Result(FeedData, RepositoryError)
alias TimeResult = Result(Time, RepositoryError)

module Fetcher
  record Entry,
    title : String,
    url : String,
    content : String,
    author : String?,
    published_at : Time?,
    source_type : String,
    version : String?
end

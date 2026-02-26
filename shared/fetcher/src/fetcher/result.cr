module Fetcher
  record Result,
    entries : Array(Entry),
    etag : String?,
    last_modified : String?,
    site_link : String?,
    favicon : String?,
    error_message : String?
end

require "./entry"
require "./result"

module Fetcher
  abstract class Driver
    abstract def pull(url : String, headers : HTTP::Headers, etag : String?, last_modified : String?) : Result

    protected def build_error_result(message : String) : Result
      Result.new(
        entries: [] of Entry,
        etag: nil,
        last_modified: nil,
        site_link: nil,
        favicon: nil,
        error_message: message
      )
    end
  end
end

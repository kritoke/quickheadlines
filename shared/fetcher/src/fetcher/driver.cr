require "./entry"
require "./result"

module Fetcher
  class RetryConfig
    property max_retries : Int32
    property base_delay : Time::Span
    property max_delay : Time::Span
    property exponential_base : Float64

    def initialize(
      @max_retries : Int32 = 3,
      @base_delay : Time::Span = 1.second,
      @max_delay : Time::Span = 30.seconds,
      @exponential_base : Float64 = 2.0
    )
    end

    def delay_forAttempt(attempt : Int32) : Time::Span
      delay = base_delay * (exponential_base ** attempt)
      delay = max_delay if delay > max_delay
      delay
    end
  end

  RETRY_CONFIG = RetryConfig.new

  abstract class Driver
    abstract def pull(url : String, headers : HTTP::Headers, etag : String?, last_modified : String?, limit : Int32 = 100) : Result

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

    protected def with_retry(max_attempts : Int32 = RETRY_CONFIG.max_retries, &)
      attempt = 0
      loop do
        begin
          return yield
        rescue ex : RetriableError
          attempt += 1
          if attempt >= max_attempts
            raise ex
          end
          delay = RETRY_CONFIG.delay_forAttempt(attempt)
          sleep(delay)
        end
      end
    end
  end

  class RetriableError < Exception
    def initialize(message : String)
      super(message)
    end
  end
end

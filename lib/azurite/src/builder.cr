module Azurite
  class Builder
    @db_path : String = Constants::DEFAULT_DB_PATH
    @retention_days : Int32 = Constants::DEFAULT_RETENTION_DAYS
    @max_size_mb : Int32 = Constants::DEFAULT_MAX_SIZE_MB
    @warning_size_mb : Int32 = Constants::DEFAULT_WARNING_SIZE_MB
    @hard_limit_mb : Int32 = Constants::DEFAULT_HARD_LIMIT_MB
    @max_content_bytes : Int32 = Constants::DEFAULT_MAX_CONTENT_BYTES

    def db_path(path : String) : self
      @db_path = path
      self
    end

    def retention_days(days : Int32) : self
      @retention_days = days
      self
    end

    def max_size_mb(size : Int32) : self
      @max_size_mb = size
      self
    end

    def warning_size_mb(size : Int32) : self
      @warning_size_mb = size
      self
    end

    def hard_limit_mb(size : Int32) : self
      @hard_limit_mb = size
      self
    end

    def max_content_bytes(bytes : Int32) : self
      @max_content_bytes = bytes
      self
    end

    def build : Store
      Store.new(
        @db_path,
        @retention_days,
        @max_size_mb,
        @warning_size_mb,
        @hard_limit_mb,
        @max_content_bytes
      )
    end
  end
end
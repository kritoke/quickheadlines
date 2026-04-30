module Azurite
  class Builder
    @db_path : String = Azurite::Constants::DEFAULT_DB_PATH
    @retention_days : Int32 = Azurite::Constants::DEFAULT_RETENTION_DAYS
    @max_size_mb : Int32 = Azurite::Constants::DEFAULT_MAX_SIZE_MB
    @warning_size_mb : Int32 = Azurite::Constants::DEFAULT_WARNING_SIZE_MB
    @hard_limit_mb : Int32 = Azurite::Constants::DEFAULT_HARD_LIMIT_MB
    @max_content_bytes : Int32 = Azurite::Constants::DEFAULT_MAX_CONTENT_BYTES
    @auto_cleanup_interval : Time::Span?

    def db_path(path : String) : self
      @db_path = path
      self
    end

    def retention_days(days : Int32) : self
      raise ArgumentError.new("retention_days must be at least 1") if days < 1
      @retention_days = days
      self
    end

    def max_size_mb(size : Int32) : self
      raise ArgumentError.new("max_size_mb must be positive") if size < 1
      @max_size_mb = size
      self
    end

    def warning_size_mb(size : Int32) : self
      raise ArgumentError.new("warning_size_mb must be at least 1") if size < 1
      @warning_size_mb = size
      self
    end

    def hard_limit_mb(size : Int32) : self
      raise ArgumentError.new("hard_limit_mb must be at least 1") if size < 1
      @hard_limit_mb = size
      self
    end

    def max_content_bytes(bytes : Int32) : self
      raise ArgumentError.new("max_content_bytes must be at least 1") if bytes < 1
      @max_content_bytes = bytes
      self
    end

    def auto_cleanup_interval(interval : Time::Span) : self
      @auto_cleanup_interval = interval
      self
    end

    def build : Store
      store = Store.new(
        @db_path,
        @retention_days,
        @max_size_mb,
        @warning_size_mb,
        @hard_limit_mb,
        @max_content_bytes
      )
      if interval = @auto_cleanup_interval
        store.start_auto_cleanup(interval)
      end
      store
    end
  end
end

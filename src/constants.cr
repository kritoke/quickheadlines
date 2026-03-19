module Constants
  # Feed fetching concurrency
  CONCURRENCY = 8

  # Cache retention settings
  CACHE_RETENTION_HOURS = 168
  CACHE_RETENTION_DAYS  =   7

  # Database size thresholds (bytes)
  DB_SIZE_WARNING_THRESHOLD = 50 * 1024 * 1024
  DB_SIZE_HARD_LIMIT        = 100 * 1024 * 1024

  # HTTP client settings
  HTTP_TIMEOUT_SECONDS    = 30
  HTTP_CONNECT_TIMEOUT    = 10
  HTTP_MAX_REDIRECTS      = 10
  HTTP_MAX_RETRIES        =  3
  HTTP_DEFAULT_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  # Clustering settings
  CLUSTERING_DEFAULT_THRESHOLD = 0.35
  CLUSTERING_DEFAULT_BANDS     =   20
  CLUSTERING_MAX_ITEMS         = 5000
  CLUSTERING_PAGE_SIZE         =  500

  # Pagination settings
  PAGINATION_DEFAULT_LIMIT  =   20
  PAGINATION_MAX_LIMIT      = 1000
  PAGINATION_TIMELINE_BATCH =   30

  # WebSocket settings
  WEBSOCKET_STALE_CONNECTION_AGE = 120 # seconds
end

module QuickHeadlines::Constants
  CONCURRENCY               =   8
  CACHE_RETENTION_HOURS     = 168
  CACHE_RETENTION_DAYS      =   7
  DB_SIZE_WARNING_THRESHOLD = 50 * 1024 * 1024
  DB_SIZE_HARD_LIMIT        = 100 * 1024 * 1024
  DB_TIME_FORMAT            = "%Y-%m-%d %H:%M:%S"

  HTTP_CONNECT_TIMEOUT   = 10
  HTTP_READ_TIMEOUT      = 30
  FETCH_TIMEOUT_SECONDS  = 60
  MAX_REDIRECTS          = 10
  MAX_RETRIES            =  3
  MAX_BACKOFF_SECONDS    = 60
  MAX_PROXY_IMAGE_BYTES  = 5 * 1024 * 1024
  MAX_CONNECTIONS        = 1000
  MAX_CONNECTIONS_PER_IP =   10
  STALE_CONNECTION_AGE   =  120
  CONNECTION_QUEUE_SIZE  =  100

  CACHE_FRESHNESS_MINUTES =   5
  FETCH_BUFFER_ITEMS      =  50
  BROADCAST_TIMEOUT_MS    = 100

  MAX_REQUEST_BODY_SIZE = 1_048_576

  ALLOWED_PROXY_DOMAINS = {
    "i.imgur.com",
    "pbs.twimg.com",
    "avatars.githubusercontent.com",
    "lh3.googleusercontent.com",
    "i.pravatar.cc",
    "images.unsplash.com",
    "fastly.picsum.photos",
  }
end

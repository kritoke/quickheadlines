module Fetcher
  module HTTPClientPool
    @@clients = {} of String => HTTP::Client

    def self.clientFor(uri : URI) : HTTP::Client
      key = "#{uri.scheme}://#{uri.host}:#{uri.port}"
      @@clients[key] ||= HTTP::Client.new(uri)
    end

    def self.clear
      @@clients.clear
    end

    def self.size
      @@clients.size
    end
  end
end

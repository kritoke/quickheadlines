#!/usr/bin/env crystal
require "./src/fav"
require "./src/favicon_storage"

urls = [
  "https://www.infoworld.com/favicon.ico",
  "https://www.google.com/s2/favicons?domain=infoworld.com&sz=256",
  "https://www.networkworld.com/favicon.ico",
  "https://www.google.com/s2/favicons?domain=networkworld.com&sz=256",
  "https://techcrunch.com/favicon.ico",
  "https://www.google.com/s2/favicons?domain=techcrunch.com&sz=256",
]

urls.each do |u|
  begin
    puts "Fetching: #{u}"
    result = fetch_favicon_uri(u)
    puts "-> #{result.inspect}\n"
  rescue ex
    STDERR.puts "Error fetching #{u}: #{ex.message}"
  end
end

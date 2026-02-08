require "../src/storage.cr"

# Simple diagnostics script that initializes the feed cache (which runs
# sync_favicon_paths on load) and prints database rows for feeds plus
# the contents of public/favicons/. This is safe to run locally and
# helps reproduce what the server does on startup.

cache = load_feed_cache(nil)

db_path = get_cache_db_path(nil)
puts "Cache DB path: #{db_path}"
if File.exists?(db_path)
  puts "Cache DB size: #{File.size(db_path)} bytes"
else
  puts "Cache DB does not exist"
end

puts "\npublic/favicons/ contents:"
if Dir.exists?("public/favicons")
  Dir.entries("public/favicons").sort.each do |name|
    next if [".", ".."].includes?(name)
    path = File.join("public/favicons", name)
    puts " - #{name} (#{File.size(path)} bytes)"
  end
else
  puts " - public/favicons directory missing"
end

puts "\nFeeds table rows (id, url, favicon, favicon_data):"
if File.exists?(db_path)
  DB.open("sqlite3://#{db_path}") do |db|
    count = db.query_one?("SELECT COUNT(*) FROM feeds", as: {Int64})
    puts "Total feeds: #{count || 0}"

    db.query("SELECT id, url, favicon, favicon_data FROM feeds") do |rows|
      rows.each do |row|
        id = row.read(Int64)
        url = row.read(String)
        favicon = row.read(String?)
        favicon_data = row.read(String?)
        puts "- #{id} | #{url} | favicon=#{favicon.inspect} | favicon_data=#{favicon_data.inspect}"
      end
    end
  end
else
  puts "No DB to query"
end

puts "\nCompleted sync_favicon_paths diagnostics."

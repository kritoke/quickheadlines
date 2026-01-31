require "json"

path = "/tmp/timeline.json"
unless File.exists?(path)
  STDERR.puts "ERROR: #{path} not found - fetch /api/timeline first"
  exit 1
end

content = File.read(path)
data = JSON.parse(content)

items = data["items"]
if items.nil? || items.size == 0
  puts "No items in timeline"
  exit 0
end

max = [items.size, 3].min
puts "Timeline sample (first #{max} items):"
(0...max).each do |i|
  it = items[i]
  title = it["title"].is_a?(JSON::Any) ? it["title"].as_s : it["title"].to_s
  feed_title = it["feed_title"].is_a?(JSON::Any) ? it["feed_title"].as_s : it["feed_title"].to_s
  favicon = it["favicon"].is_a?(JSON::Any) ? it["favicon"].as_s : (it["favicon"] ? it["favicon"].to_s : "(nil)")
  puts "- #{i + 1}) title: #{title}"
  puts "     feed: #{feed_title}"
  puts "     favicon: #{favicon}"
end

puts "\nDone."

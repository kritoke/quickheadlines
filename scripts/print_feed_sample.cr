require "json"

path = "/tmp/feeds.json"
unless File.exists?(path)
  STDERR.puts "ERROR: #{path} not found"
  exit 1
end

content = File.read(path)
data = JSON.parse(content)

feeds = data["feeds"]
if feeds.nil? || feeds.size == 0
  puts "No feeds found in #{path}"
  exit 0
end

first = feeds[0]

def maybe_str(a)
  return nil if a.nil?
  if a.is_a?(JSON::Any)
    begin
      a.as_s
    rescue
      a.to_s
    end
  else
    a.to_s
  end
rescue
  nil
end

puts "Feed sample (first feed):"
puts "- title: #{maybe_str(first["title"]) || "(nil)"}"
puts "- url: #{maybe_str(first["url"]) || "(nil)"}"
puts "- site_link: #{maybe_str(first["site_link"]) || "(nil)"}"
puts "- favicon: #{maybe_str(first["favicon"]) || "(nil)"}"
puts "- favicon_data: #{maybe_str(first["favicon_data"]) || "(nil)"}"

items = first["items"]
items = [] of JSON::Any if items.nil?
puts "- items (first up to 3):"
items_to_show = [] of JSON::Any
max = [items.size, 3].min
(0...max).each do |idx|
  items_to_show << items[idx]
end

items_to_show.each_with_index do |it, i|
  title = maybe_str(it["title"]) || "(nil)"
  link = maybe_str(it["link"]) || "(nil)"
  pub = it["pub_date"]
  pub_s = if pub.nil?
    "(nil)"
  else
    maybe_str(pub) || "(nil)"
  end
  puts "  #{i+1}) title: #{title}"
  puts "     link: #{link}"
  puts "     pub_date(ms): #{pub_s}"
end

puts "\nDone."

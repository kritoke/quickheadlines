require "http/client"
require "./models"
require "./parser"

# Generic code icon (SVG) representing software/programming
CODE_ICON = "internal:code_icon"

def fetch_sw_with_config(sw_config : SoftwareConfig, item_limit : Int32) : FeedData?
  items = [] of Item
  sw_config.repos.each do |repo_entry|
    if item = fetch_repo(repo_entry, item_limit)
      items << item
    end
  end

  return nil if items.empty?

  items.sort_by! { |i| i.pub_date || Time.unix(0) }.reverse!

  FeedData.new(
    title: sw_config.title,
    url: "software://releases",
    site_link: "https://github.com", # Default landing
    header_color: sw_config.header_color || "#24292e",
    items: items,
    favicon_data: CODE_ICON
  )
end

private def fetch_repo(repo_entry : String, item_limit : Int32) : Item?
  parts = repo_entry.split(':')
  repo_path = parts[0]
  provider = parts[1]? || "gh"

  url = case provider
        when "gl" then "https://gitlab.com/#{repo_path}/-/releases.atom"
        when "cb" then "https://codeberg.org/#{repo_path}/releases.atom"
        else           "https://github.com/#{repo_path}/releases.atom"
        end

  begin
    response = HTTP::Client.get(url)
    if response.status_code == 200
      parsed = parse_feed(IO::Memory.new(response.body), item_limit)
      if latest = parsed[:items].first?
        return Item.new(repo_path, latest.link, latest.pub_date, latest.title)
      end
    elsif provider == "gl" && response.status_code == 404
      return gl_tag(repo_path, item_limit)
    end
  rescue ex
    STDERR.puts "Error fetching #{provider} repo #{repo_path}: #{ex.message}"
  end
  nil
end

private def gl_tag(repo_path : String, item_limit : Int32) : Item?
  tag_url = "https://gitlab.com/#{repo_path}/-/tags?format=atom"
  tag_res = HTTP::Client.get(tag_url)
  if tag_res.status_code == 200
    parsed = parse_feed(IO::Memory.new(tag_res.body), item_limit)
    if latest = parsed[:items].first?
      return Item.new(repo_path, latest.link, latest.pub_date, latest.title)
    end
  end
  nil
rescue
  nil
end

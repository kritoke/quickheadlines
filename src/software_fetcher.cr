require "http/client"
require "./models"
require "./parser"

# Generic code icon (SVG) representing software/programming
CODE_ICON = "internal:code_icon"

def fetch_software_releases(config : Config) : FeedData?
  sw_config = config.software_releases
  return nil unless sw_config

  items = [] of Item
  sw_config.repos.each do |repo_entry|
    # Support "owner/repo:type" format, default to gh
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
        # Parse only the latest entry for this specific repo
        parsed = parse_feed(IO::Memory.new(response.body), 1)
        if latest = parsed[:items].first?
          items << Item.new(repo_path, latest.link, latest.pub_date, latest.title)
        end
      elsif provider == "gl" && response.status_code == 404
        # GitLab fallback: some projects use tags instead of formal releases
        tag_url = "https://gitlab.com/#{repo_path}/-/tags?format=atom"
        tag_res = HTTP::Client.get(tag_url)
        if tag_res.status_code == 200
          parsed = parse_feed(IO::Memory.new(tag_res.body), 1)
          if latest = parsed[:items].first?
            items << Item.new(repo_path, latest.link, latest.pub_date, latest.title)
          end
        end
      end
    rescue ex
      STDERR.puts "Error fetching #{provider} repo #{repo_path}: #{ex.message}"
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
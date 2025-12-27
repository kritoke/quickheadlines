require "http/client"
require "./models"
require "./parser"

def fetch_github_releases(config : Config) : FeedData?
  gh_config = config.github_releases
  return nil unless gh_config

  items = [] of Item
  gh_config.repos.each do |repo_path|
    url = "https://github.com/#{repo_path}/releases.atom"
    begin
      response = HTTP::Client.get(url)
      if response.status_code == 200
        # Parse only the latest entry for this specific repo
        parsed = parse_feed(IO::Memory.new(response.body), 1)
        if latest = parsed[:items].first?
          # Use the full repo path (user/repo) as title and the release title as version
          items << Item.new(repo_path, latest.link, latest.pub_date, latest.title)
        end
      end
    rescue ex
      STDERR.puts "Error fetching GitHub repo #{repo_path}: #{ex.message}"
    end
  end

  return nil if items.empty?

  # Sort all releases by date descending so the newest updates appear at the top of the box
  items.sort_by! { |i| i.pub_date || Time.unix(0) }.reverse!

  FeedData.new(
    title: gh_config.title,
    url: "github://releases",
    site_link: "https://github.com",
    header_color: gh_config.header_color || "#24292e",
    items: items,
    favicon: "https://github.com/favicon.ico"
  )
end
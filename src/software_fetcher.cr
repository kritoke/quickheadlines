require "http/client"
require "json"
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

  return if items.empty?

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

  case provider
  when "gh" then fetch_github_release(repo_path, item_limit)
  when "gl" then fetch_gitlab_release(repo_path, item_limit)
  when "cb" then fetch_codeberg_release(repo_path, item_limit)
  end
end

private def fetch_github_release(repo_path : String, item_limit : Int32) : Item?
  url = "https://api.github.com/repos/#{repo_path}/releases"

  begin
    response = HTTP::Client.get(url, HTTP::Headers{"Accept" => "application/vnd.github.v3+json"})
    if response.status_code == 200
      # Parse JSON response
      releases = Array(JSON::Any).from_json(response.body)

      # Filter out prereleases and drafts, get first stable release
      stable_releases = releases.reject do |release|
        release["prerelease"].as_bool || release["draft"].as_bool
      end

      if release = stable_releases.first?
        tag_name = release["tag_name"].as_s
        release_name = release["name"].as_s.presence || tag_name
        html_url = release["html_url"].as_s
        published_at = release["published_at"].as_s

        # Parse the published date
        pub_date = Time.parse_iso8601(published_at)

        return Item.new(repo_path, html_url, pub_date, release_name)
      end
    end
  rescue ex
    STDERR.puts "Error fetching GitHub repo #{repo_path}: #{ex.message}"
  end

  nil
end

private def fetch_gitlab_release(repo_path : String, item_limit : Int32) : Item?
  url = "https://gitlab.com/#{repo_path}/-/releases.atom"

  begin
    response = HTTP::Client.get(url)
    if response.status_code == 200
      parsed = parse_feed(IO::Memory.new(response.body), item_limit)
      if latest = parsed[:items].first?
        return Item.new(repo_path, latest.link, latest.pub_date, latest.title)
      end
    elsif response.status_code == 404
      return gl_tag(repo_path, item_limit)
    end
  rescue ex
    STDERR.puts "Error fetching GitLab repo #{repo_path}: #{ex.message}"
  end

  nil
end

private def fetch_codeberg_release(repo_path : String, item_limit : Int32) : Item?
  url = "https://codeberg.org/#{repo_path}/releases.atom"

  begin
    response = HTTP::Client.get(url)
    if response.status_code == 200
      parsed = parse_feed(IO::Memory.new(response.body), item_limit)
      if latest = parsed[:items].first?
        return Item.new(repo_path, latest.link, latest.pub_date, latest.title)
      end
    end
  rescue ex
    STDERR.puts "Error fetching Codeberg repo #{repo_path}: #{ex.message}"
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

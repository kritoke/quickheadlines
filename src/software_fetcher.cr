require "fetcher"
require "./models"
require "./fetcher/feed_fetcher"

CODE_ICON = "internal:code_icon"

def fetch_sw_with_config(sw_config : SoftwareConfig, item_limit : Int32) : FeedData?
  latest_by_repo = Hash(String, Item).new
  sw_config.repos.each do |repo_entry|
    if releases = fetch_repo_release(repo_entry, item_limit)
      next if releases.empty?
      latest_by_repo[repo_entry] = releases.first
    end
  end

  return if latest_by_repo.empty?

  items = latest_by_repo.values.to_a
  items.sort_by! { |i| i.pub_date || Time.unix(0) }.reverse!

  FeedData.new(
    title: sw_config.title,
    url: "software://releases",
    site_link: "https://github.com",
    header_color: sw_config.header_color || "#24292e",
    header_text_color: sw_config.header_text_color,
    items: items,
    favicon_data: CODE_ICON
  )
end

private def fetch_repo_release(repo_entry : String, item_limit : Int32) : Array(Item)?
  url = repo_entry_to_url(repo_entry)
  return unless url

  result = Fetcher.pull_software(url, HTTP::Headers.new, item_limit, fetcher_config)

  if error = result.error_message
    Log.for("quickheadlines.feed").warn { "Error fetching software releases for #{repo_entry}: #{error}" }
    return
  end

  return if result.entries.empty?

  result.entries.map do |entry|
    Item.new(
      title: entry.title,
      link: entry.url,
      pub_date: entry.published_at,
      version: entry.version,
      comment_url: nil,
      commentary_url: nil
    )
  end
rescue ex
  Log.for("quickheadlines.feed").error(exception: ex) { "Error fetching software releases for #{repo_entry}" }
  nil
end

private def repo_entry_to_url(repo_entry : String) : String?
  parts = repo_entry.split(':')
  repo_path = parts[0]
  provider = parts[1]? || "gh"

  case provider
  when "gh"
    "https://github.com/#{repo_path}/releases"
  when "gl"
    "https://gitlab.com/#{repo_path}/-/releases"
  when "cb"
    "https://codeberg.org/#{repo_path}/releases"
  else
    Log.for("quickheadlines.feed").warn { "Unknown provider '#{provider}' for repo #{repo_path}" }
    nil
  end
end

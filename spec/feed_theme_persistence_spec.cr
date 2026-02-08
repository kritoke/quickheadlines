require "spec"
require "../src/storage"

describe "Feed Theme Persistence" do
  it "persists header_theme_colors on insert and update" do
    cache = FeedCache.new(nil)

    theme_json = {"bg" => "rgb(10,20,30)", "text" => {"light" => "#ffffff", "dark" => "#000000"}, "source" => "auto"}.to_json

    fd = FeedData.new(
      title: "Theme Feed",
      url: "https://theme.example.com/feed.xml",
      site_link: "https://theme.example.com",
      header_color: nil,
      header_text_color: nil,
      items: [] of Item
    )
    fd.header_theme_colors = theme_json

    # Insert
    cache.add(fd)

    saved = cache.get_feed_theme_colors("https://theme.example.com/feed.xml")
    saved.should_not be_nil
    saved.should eq(theme_json)

    # Update with new theme
    new_theme = {"bg" => "rgb(100,110,120)", "text" => {"light" => "#f0f0f0", "dark" => "#0f0f0f"}, "source" => "override"}.to_json
    fd2 = cache.get("https://theme.example.com/feed.xml")
    fd2.should_not be_nil
    if fd2
      fd2.header_theme_colors = new_theme
      cache.add(fd2)
    else
      raise "FeedData missing after insert"
    end

    updated = cache.get_feed_theme_colors("https://theme.example.com/feed.xml")
    updated.should eq(new_theme)
  end
end

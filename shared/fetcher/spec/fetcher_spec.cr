require "http/client"
require "../src/fetcher"
require "spec"

describe Fetcher::Entry do
  it "creates entry with required fields" do
    entry = Fetcher::Entry.new(
      title: "Test Title",
      url: "https://example.com",
      content: "Test content",
      author: nil,
      published_at: nil,
      source_type: "rss",
      version: nil
    )
    entry.title.should eq("Test Title")
    entry.url.should eq("https://example.com")
    entry.source_type.should eq("rss")
  end

  it "creates entry with all fields" do
    time = Time.utc(2024, 1, 15, 10, 30, 0)
    entry = Fetcher::Entry.new(
      title: "Test Title",
      url: "https://example.com",
      content: "Test content",
      author: "author",
      published_at: time,
      source_type: "rss",
      version: "1.0.0"
    )
    entry.title.should eq("Test Title")
    entry.author.should eq("author")
    entry.published_at.should eq(time)
    entry.version.should eq("1.0.0")
  end
end

describe Fetcher::Result do
  it "creates result with entries" do
    entry = Fetcher::Entry.new(
      title: "Test",
      url: "https://example.com",
      content: "",
      author: nil,
      published_at: nil,
      source_type: "rss",
      version: nil
    )
    result = Fetcher::Result.new(
      entries: [entry],
      etag: nil,
      last_modified: nil,
      site_link: "https://example.com",
      favicon: nil,
      error_message: nil
    )
    result.entries.size.should eq(1)
    result.site_link.should eq("https://example.com")
  end

  it "can hold error message" do
    result = Fetcher::Result.new(
      entries: [] of Fetcher::Entry,
      etag: nil,
      last_modified: nil,
      site_link: nil,
      favicon: nil,
      error_message: "Network error"
    )
    result.error_message.should eq("Network error")
  end

  it "can hold etag and last_modified" do
    result = Fetcher::Result.new(
      entries: [] of Fetcher::Entry,
      etag: "abc123",
      last_modified: "Wed, 15 Jan 2024 10:00:00 GMT",
      site_link: nil,
      favicon: nil,
      error_message: nil
    )
    result.etag.should eq("abc123")
    result.last_modified.should eq("Wed, 15 Jan 2024 10:00:00 GMT")
  end
end

describe Fetcher::RSSDriver do
  it "can be instantiated" do
    driver = Fetcher::RSSDriver.new
    driver.should be_a(Fetcher::Driver)
  end

  it "returns error for invalid URL" do
    driver = Fetcher::RSSDriver.new
    result = driver.pull("http://invalid.invalid.test/feed.xml", HTTP::Headers.new, nil, nil)
    result.error_message.should_not be_nil
  end
end

describe Fetcher::RedditDriver do
  it "can be instantiated" do
    driver = Fetcher::RedditDriver.new
    driver.should be_a(Fetcher::Driver)
  end

  it "returns error for non-reddit URL" do
    driver = Fetcher::RedditDriver.new
    result = driver.pull("https://example.com/feed.xml", HTTP::Headers.new, nil, nil)

    result.error_message.should eq("Not a Reddit subreddit URL")
  end
end

describe Fetcher::SoftwareDriver do
  it "can be instantiated" do
    driver = Fetcher::SoftwareDriver.new
    driver.should be_a(Fetcher::Driver)
  end

  it "returns error for non-software URL" do
    driver = Fetcher::SoftwareDriver.new
    result = driver.pull("https://example.com/feed.xml", HTTP::Headers.new, nil, nil)

    result.error_message.should eq("Unknown software provider")
  end

  it "returns error for invalid GitHub URL (no releases path)" do
    driver = Fetcher::SoftwareDriver.new
    result = driver.pull("https://github.com/invalid/repo", HTTP::Headers.new, nil, nil)

    result.error_message.should eq("Unknown software provider")
  end
end

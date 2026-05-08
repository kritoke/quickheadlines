require "spec"
require "../src/utils"

describe "UrlNormalizer" do
  it "upgrades http to https and strips www and feed paths" do
    UrlNormalizer.normalize("http://www.example.com/feed.xml").should eq("https://example.com")
    UrlNormalizer.normalize("http://example.com/rss").should eq("https://example.com")
  end

  it "removes query string and fragment" do
    UrlNormalizer.normalize("https://example.com/page?utm=1#section").should eq("https://example.com/page")
  end

  it "removes trailing slash and www prefix" do
    UrlNormalizer.normalize("https://www.example.com/").should eq("https://example.com")
  end

  it "preserves non-feed paths" do
    UrlNormalizer.normalize("https://example.com/articles/2026").should eq("https://example.com/articles/2026")
  end
end

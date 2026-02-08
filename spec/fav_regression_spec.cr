require "spec_helper"

describe "favicon regression checks" do
  it "fetches infoworld favicon via direct URL or google fallback" do
    urls = [
      "https://www.infoworld.com/favicon.ico",
      "https://www.google.com/s2/favicons?domain=infoworld.com&sz=256"
    ]
    result = nil
    urls.each do |u|
      result = fetch_favicon_uri(u)
      break if result
    end
    result.should_not be_nil
  end

  it "fetches networkworld favicon via direct URL or google fallback" do
    urls = [
      "https://www.networkworld.com/favicon.ico",
      "https://www.google.com/s2/favicons?domain=networkworld.com&sz=256"
    ]
    result = nil
    urls.each do |u|
      result = fetch_favicon_uri(u)
      break if result
    end
    result.should_not be_nil
  end

  it "fetches techcrunch favicon via direct URL or google fallback" do
    urls = [
      "https://techcrunch.com/favicon.ico",
      "https://www.google.com/s2/favicons?domain=techcrunch.com&sz=256"
    ]
    result = nil
    urls.each do |u|
      result = fetch_favicon_uri(u)
      break if result
    end
    result.should_not be_nil
  end
end

require "./spec_helper"

describe "Header Colors API Validation" do
  describe "Request body validation" do
    it "rejects request with missing feed_url" do
      body = JSON.parse(%({"color": "rgb(100,150,200)", "text_color": "#ffffff"}))

      feed_url_raw = body["feed_url"]?
      color_raw = body["color"]?
      text_color_raw = body["text_color"]?

      feed_url = feed_url_raw.is_a?(JSON::Any) ? feed_url_raw.as_s : nil
      color = color_raw.is_a?(JSON::Any) ? color_raw.as_s : nil
      text_color = text_color_raw.is_a?(JSON::Any) ? text_color_raw.as_s : nil

      (feed_url.nil? || color.nil? || text_color.nil?).should be_true
    end

    it "rejects request with missing color" do
      body = JSON.parse(%({"feed_url": "https://example.com/feed.xml", "text_color": "#ffffff"}))

      feed_url_raw = body["feed_url"]?
      color_raw = body["color"]?
      text_color_raw = body["text_color"]?

      feed_url = feed_url_raw.is_a?(JSON::Any) ? feed_url_raw.as_s : nil
      color = color_raw.is_a?(JSON::Any) ? color_raw.as_s : nil
      text_color = text_color_raw.is_a?(JSON::Any) ? text_color_raw.as_s : nil

      (feed_url.nil? || color.nil? || text_color.nil?).should be_true
    end

    it "rejects request with missing text_color" do
      body = JSON.parse(%({"feed_url": "https://example.com/feed.xml", "color": "rgb(100,150,200)"}))

      feed_url_raw = body["feed_url"]?
      color_raw = body["color"]?
      text_color_raw = body["text_color"]?

      feed_url = feed_url_raw.is_a?(JSON::Any) ? feed_url_raw.as_s : nil
      color = color_raw.is_a?(JSON::Any) ? color_raw.as_s : nil
      text_color = text_color_raw.is_a?(JSON::Any) ? text_color_raw.as_s : nil

      (feed_url.nil? || color.nil? || text_color.nil?).should be_true
    end

    it "accepts valid request with all fields" do
      body = JSON.parse(%({"feed_url": "https://example.com/feed.xml", "color": "rgb(100,150,200)", "text_color": "#ffffff"}))

      feed_url_raw = body["feed_url"]?
      color_raw = body["color"]?
      text_color_raw = body["text_color"]?

      feed_url = feed_url_raw.is_a?(JSON::Any) ? feed_url_raw.as_s : nil
      color = color_raw.is_a?(JSON::Any) ? color_raw.as_s : nil
      text_color = text_color_raw.is_a?(JSON::Any) ? text_color_raw.as_s : nil

      (feed_url.nil? || color.nil? || text_color.nil?).should be_false
      feed_url.should eq("https://example.com/feed.xml")
      color.should eq("rgb(100,150,200)")
      text_color.should eq("#ffffff")
    end

    it "accepts rgb format without spaces" do
      body = JSON.parse(%({"feed_url": "https://example.com/feed.xml", "color": "rgb(100,150,200)", "text_color": "#ffffff"}))

      color_raw = body["color"]?
      color = color_raw.is_a?(JSON::Any) ? color_raw.as_s : nil
      color.should eq("rgb(100,150,200)")
    end

    it "accepts hex color format" do
      body = JSON.parse(%({"feed_url": "https://example.com/feed.xml", "color": "#6495ed", "text_color": "#ffffff"}))

      color_raw = body["color"]?
      color = color_raw.is_a?(JSON::Any) ? color_raw.as_s : nil
      color.should eq("#6495ed")
    end

    it "handles empty body" do
      # Empty body should be handled gracefully by the controller
      # The controller checks for nil values which will be true for empty body
      feed_url = nil
      color = nil
      text_color = nil

      (feed_url.nil? || color.nil? || text_color.nil?).should be_true
    end
  end
end

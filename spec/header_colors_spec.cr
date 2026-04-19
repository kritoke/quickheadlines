require "./spec_helper"

describe "Header Colors" do
  describe FeedCache do
    describe "update_header_colors" do
      it "saves bg and text colors for feed with existing colors" do
        cache = create_test_feed_cache

        # First add a feed with items (required for add to work)
        test_feed = FeedData.new(
          title: "Test Feed",
          url: "https://test.com/feed.xml",
          site_link: "https://test.com",
          header_color: nil,
          header_text_color: nil,
          items: [] of Item,
          etag: nil,
          last_modified: nil,
          favicon: nil,
          favicon_data: nil
        )
        cache.add(test_feed)

        # Update colors
        cache.update_header_colors("https://test.com/feed.xml", "rgb(200,200,200)", "#ffffff")

        # Verify via get
        feed = cache.get("https://test.com/feed.xml")
        feed.should_not be_nil
        feed.not_nil!.header_color.should eq("rgb(200,200,200)")
        feed.not_nil!.header_text_color.should eq("#ffffff")
      end
    end
  end
end

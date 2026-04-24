require "../software_fetcher"

module QuickHeadlines::SoftwareUtil
  def self.build_software_releases(software_config : SoftwareConfig?, item_limit : Int32) : Array(FeedData)
    return [] of FeedData unless software_config
    feed = fetch_sw_with_config(software_config, item_limit)
    feed ? [feed] : [] of FeedData
  end
end

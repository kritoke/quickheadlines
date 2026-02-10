type FeedSource {
  FeedSource(
    id : Number,
    name : String,
    url : String,
    favicon : String,
    headerColor : String,
    headerTextColor : String,
    articles : Array(TimelineItem)
  )
}

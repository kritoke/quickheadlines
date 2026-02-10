module Api {
  fun fetchTimeline(limit : Number, offset : Number) : Promise(Array(TimelineItem)) {
    Http.get("/api/timeline?limit=\(limit)&offset=\(offset)")
      |> then (response : Http.Response) {
        if (response.ok) {
          response.json()
            |> then (data : Any) {
              Ok(decodeTimelineItems(data["items"]))
            }
        } else {
          Error(decodeTimelineItems([]))
        }
      }
      |> catch (error : Http.Error) {
        Error(decodeTimelineItems([]))
      }
  }

  fun decodeTimelineItems(items : Array(Any)) : Array(TimelineItem) {
    items.map((item : Any) {
      TimelineItem(
        id: item["id"],
        title: item["title"],
        link: item["link"],
        pubDate: item["pubDate"],
        feedTitle: item["feedTitle"],
        feedUrl: item["feedUrl"],
        feedLink: item["feedLink"],
        favicon: item["favicon"],
        headerColor: item["headerColor"],
        headerTextColor: item["headerTextColor"],
        clusterId: item["clusterId"],
        isRepresentative: item["isRepresentative"] or false,
        clusterSize: item["clusterSize"]
      )
    })
  }
}

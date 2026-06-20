## JSON DTOs for the HTTP layer - shapes match the frozen API.md (camelCase,
## dates as UNIX-ms). Sole place that knows the wire JSON shape.

import std/[json, times, options, sequtils]
import ../types

const DbTimeFormat* = "yyyy-MM-dd HH:mm:ss"

proc toMillis(s: string): int64 =
  ## "yyyy-MM-dd HH:mm:ss" (UTC) -> UNIX millis. 0 if unparseable.
  if s.len == 0: return 0
  try:
    result = parse(s, DbTimeFormat, utc()).toTime().toUnix() * 1000'i64
  except CatchableError:
    result = 0

proc jstr(v: string): JsonNode =
  if v.len == 0: newJNull() else: %v
proc jstrOr(v: string; dflt = ""): JsonNode =
  %(if v.len == 0: dflt else: v)

proc timelineItemJson*(e: TimelineEntry): JsonNode =
  %{
    "id": %($e.id),
    "title": %e.title,
    "link": %e.link,
    "pub_date": %(toMillis(e.pubDate)),
    "feed_title": %e.feedTitle,
    "feed_url": %e.feedUrl,
    "feed_link": %e.feedLink,
    "favicon": jstrOr(e.favicon),
    "header_color": jstr(e.headerColor),
    "header_text_color": jstr(e.headerTextColor),
    "cluster_id": (if e.clusterId == 0: newJNull() else: %($e.clusterId)),
    "is_representative": %e.representative,
    "cluster_size": %e.clusterSize
  }

proc timelineJson*(entries: seq[TimelineEntry]; total: int; limit: int): JsonNode =
  ## { items: [...], has_more, total_count }
  %{
    "items": %(entries.mapIt(timelineItemJson(it))),
    "has_more": %(entries.len < total and entries.len >= limit),
    "total_count": %total
  }

proc itemJson*(it: Item): JsonNode =
  %*{"title": %it.title, "link": %it.link, "pub_date": %(toMillis(it.pubDate)),
     "content": %it.content, "version": %it.version,
     "comment_url": %it.commentUrl, "commentary_url": %it.commentaryUrl}

proc feedJson*(f: FeedRow; items: seq[Item]; itemCount: int): JsonNode =
  %{
    "tab": %"",
    "url": %f.url,
    "title": %f.title,
    "display_link": %f.siteLink,
    "site_link": %f.siteLink,
    "favicon": jstrOr(f.favicon),
    "favicon_data": jstrOr(f.faviconData),
    "header_color": jstr(f.headerColor),
    "header_text_color": jstr(f.headerTextColor),
    "items": %(items.mapIt(itemJson(it))),
    "total_item_count": %itemCount
  }

proc statusJson*(isClustering: bool; activeJobs: int): JsonNode =
  %{"is_clustering": %isClustering, "active_jobs": %activeJobs}

proc versionJson*(updatedAtMs: int64): JsonNode = %{"updated_at": %updatedAtMs}

proc configJson*(c: Config): JsonNode =
  ## ConfigResponse: {refresh_minutes, item_limit, debug}
  %{"refresh_minutes": %c.refreshMinutes, "item_limit": %c.itemLimit, "debug": %c.debug}

proc tabsJson*(tabs: seq[TabConfig]): JsonNode =
  var t: seq[JsonNode]
  for x in tabs: t.add(%*{"name": %x.name})
  %{"tabs": %t}

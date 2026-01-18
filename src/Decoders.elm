module Decoders exposing (..)

import Json.Decode exposing (Decoder, bool, field, int, list, map, map3, map4, nullable, string, succeed)
import Json.Decode.Pipeline exposing (optional, required, requiredAt)
import Time exposing (Posix, millisToPosix)
import Types exposing (..)


feedDecoder : Decoder Feed
feedDecoder =
    succeed Feed
        |> required "tab" string
        |> required "url" string
        |> required "title" string
        |> required "display_link" string
        |> required "site_link" string
        |> optional "favicon" string ""
        |> optional "favicon_data" string ""
        |> optional "header_color" (nullable string) Nothing
        |> required "items" (list feedItemDecoder)
        |> required "total_item_count" int


feedItemDecoder : Decoder FeedItem
feedItemDecoder =
    succeed FeedItem
        |> required "title" string
        |> required "link" string
        |> optional "version" (nullable string) Nothing
        |> optional "pub_date" (nullable (map millisToPosix int)) Nothing


tabDecoder : Decoder Tab
tabDecoder =
    map Tab (field "name" string)


timelineItemDecoder : Decoder TimelineItem
timelineItemDecoder =
    succeed TimelineItem
        |> required "id" string
        |> required "title" string
        |> required "link" string
        |> optional "pub_date" (nullable (map millisToPosix int)) Nothing
        |> required "feed_title" string
        |> required "feed_url" string
        |> required "feed_link" string
        |> optional "favicon" string ""
        |> optional "favicon_data" string ""
        |> optional "header_color" (nullable string) Nothing
        |> optional "cluster_id" (nullable string) Nothing
        |> required "is_representative" bool
        |> optional "cluster_size" (nullable int) Nothing


feedsDecoder : Decoder (List Feed)
feedsDecoder =
    list feedDecoder


timelineItemsDecoder : Decoder (List TimelineItem)
timelineItemsDecoder =
    list timelineItemDecoder


tabsDecoder : Decoder (List Tab)
tabsDecoder =
    list tabDecoder


feedsPageDecoder : Decoder { tabs : List Tab, activeTab : String, feeds : List Feed }
feedsPageDecoder =
    map3 (\tabs activeTab feeds -> { tabs = tabs, activeTab = activeTab, feeds = feeds })
        (field "tabs" (list tabDecoder))
        (field "active_tab" string)
        (field "feeds" (list feedDecoder))


type alias TimelinePage =
    { items : List TimelineItem, hasMore : Bool, totalCount : Int }


timelinePageDecoder : Decoder TimelinePage
timelinePageDecoder =
    map3 TimelinePage
        (field "items" (list timelineItemDecoder))
        (field "has_more" bool)
        (field "total_count" int)


versionDecoder : Decoder Posix
versionDecoder =
    map millisToPosix (field "updated_at" int)


errorDecoder : Decoder String
errorDecoder =
    field "message" string

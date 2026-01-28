module Api exposing (FeedsResponse, Feed, FeedItem, Tab, TimelineItem, TimelineResponse, fetchFeeds, fetchTimeline)

import Http
import Json.Decode as Decode exposing (Decoder, field, list, nullable, string, succeed)
import Time


type alias Tab = { name : String }


type alias FeedItem =
    { title : String
    , link : String
    , pubDate : Maybe Time.Posix
    }


type alias Feed =
    { tab : String
    , url : String
    , title : String
    , displayLink : String
    , siteLink : String
    , favicon : Maybe String
    , headerColor : Maybe String
    , headerTextColor : Maybe String
    , items : List FeedItem
    , totalItemCount : Int
    }


type alias FeedsResponse =
    { tabs : List Tab
    , activeTab : String
    , feeds : List Feed
    }


type alias TimelineItem =
    { id : String
    , title : String
    , link : String
    , pubDate : Maybe Time.Posix
    , feedTitle : String
    , favicon : Maybe String
    , headerColor : Maybe String
    , headerTextColor : Maybe String
    , clusterId : Maybe String
    , isRepresentative : Bool
    , clusterSize : Int
    }


type alias TimelineResponse =
    { items : List TimelineItem
    , hasMore : Bool
    , totalCount : Int
    }


feedDecoder : Decoder Feed
feedDecoder =
    Decode.field "tab" string
        |> Decode.andThen (\tab ->
            Decode.field "url" string
                |> Decode.andThen (\url ->
                    Decode.field "title" string
                        |> Decode.andThen (\title ->
                            Decode.field "display_link" string
                                |> Decode.andThen (\displayLink ->
                                    Decode.field "site_link" string
                                        |> Decode.andThen (\siteLink ->
                                            Decode.field "favicon" (nullable string)
                                                |> Decode.andThen (\favicon ->
                                                    Decode.field "header_color" (nullable string)
                                                        |> Decode.andThen (\headerColor ->
                                                            Decode.field "header_text_color" (nullable string)
                                                                |> Decode.andThen (\headerTextColor ->
                                                                    Decode.field "items" (list feedItemDecoder)
                                                                        |> Decode.andThen (\items ->
                                                                            Decode.field "total_item_count" Decode.int
                                                                                |> Decode.andThen (\totalItemCount ->
                                                                                    Decode.succeed
                                                                                        { tab = tab
                                                                                        , url = url
                                                                                        , title = title
                                                                                        , displayLink = displayLink
                                                                                        , siteLink = siteLink
                                                                                        , favicon = favicon
                                                                                        , headerColor = headerColor
                                                                                        , headerTextColor = headerTextColor
                                                                                        , items = items
                                                                                        , totalItemCount = totalItemCount
                                                                                        }
                                                                                )
                                                                        )
                                                                )
                                                        )
                                                )
                                        )
                                )
                        )
                )
        )


feedItemDecoder : Decoder FeedItem
feedItemDecoder =
    Decode.map3 FeedItem
        (field "title" string)
        (field "link" string)
        (field "pub_date" (nullable (Decode.map Time.millisToPosix Decode.int)))


tabDecoder : Decoder Tab
tabDecoder =
    Decode.map Tab (field "name" string)


feedsDecoder : Decoder FeedsResponse
feedsDecoder =
    Decode.map3 FeedsResponse
        (field "tabs" (list tabDecoder))
        (field "active_tab" string)
        (field "feeds" (list feedDecoder))


fetchFeeds : String -> (Result Http.Error FeedsResponse -> msg) -> Cmd msg
fetchFeeds tab tagger =
    Http.get
        { url = "/api/feeds?tab=" ++ tab
        , expect = Http.expectJson tagger feedsDecoder
        }


timelineItemDecoder : Decoder TimelineItem
timelineItemDecoder =
    Decode.field "id" string
        |> Decode.andThen (\id ->
            Decode.field "title" string
                |> Decode.andThen (\title ->
                    Decode.field "link" string
                        |> Decode.andThen (\link ->
                            Decode.field "pub_date" (nullable (Decode.map Time.millisToPosix Decode.int))
                                |> Decode.andThen (\pubDate ->
                                    Decode.field "feed_title" string
                                        |> Decode.andThen (\feedTitle ->
                                            Decode.field "favicon" (nullable string)
                                                |> Decode.andThen (\favicon ->
                                                    Decode.field "header_color" (nullable string)
                                                        |> Decode.andThen (\headerColor ->
                                                            Decode.field "header_text_color" (nullable string)
                                                                |> Decode.andThen (\headerTextColor ->
                                                                    Decode.field "cluster_id" (nullable string)
                                                                        |> Decode.andThen (\clusterId ->
                                                                            Decode.field "is_representative" Decode.bool
                                                                                |> Decode.andThen (\isRepresentative ->
                                                                                    Decode.field "cluster_size" (nullable Decode.int)
                                                                                        |> Decode.andThen (\clusterSize ->
                                                                                             succeed
                                                                                                 { id = id
                                                                                                 , title = title
                                                                                                 , link = link
                                                                                                 , pubDate = pubDate
                                                                                                 , feedTitle = feedTitle
                                                                                                 , favicon = favicon
                                                                                                 , headerColor = headerColor
                                                                                                 , headerTextColor = headerTextColor
                                                                                                 , clusterId = clusterId
                                                                                                 , isRepresentative = isRepresentative
                                                                                                 , clusterSize = Maybe.withDefault 0 clusterSize
                                                                                                 }
                                                                                        )
                                                                                )
                                                                        )
                                                                )
                                                        )
                                                )
                                        )
                                )
                        )
                )
        )


timelineDecoder : Decoder TimelineResponse
timelineDecoder =
    Decode.map3 TimelineResponse
        (field "items" (list timelineItemDecoder))
        (field "has_more" Decode.bool)
        (field "total_count" Decode.int)


fetchTimeline : Int -> Int -> (Result Http.Error TimelineResponse -> msg) -> Cmd msg
fetchTimeline limit offset tagger =
    Http.get
        { url = "/api/timeline?limit=" ++ String.fromInt limit ++ "&offset=" ++ String.fromInt offset
        , expect = Http.expectJson tagger timelineDecoder
        }

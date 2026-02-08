module Api exposing (Cluster, ClusterItem, Feed, FeedItem, FeedsResponse, Tab, TimelineItem, TimelineResponse, clusterItemsFromTimeline, fetchFeedMore, fetchFeeds, fetchTimeline, sortFeedItems, sortTimelineItems)

import Http
import Json.Decode as JD exposing (Decoder, field, list, nullable, string)
import Time
import Url


type alias Tab =
    { name : String }


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
    , headerTheme : Maybe JD.Value
    , items : List FeedItem
    , totalItemCount : Int
    }


type alias FeedsResponse =
    { tabs : List Tab
    , activeTab : String
    , feeds : List Feed
    , isClustering : Bool
    }


type alias TimelineResponse =
    { items : List TimelineItem
    , hasMore : Bool
    , totalCount : Int
    , isClustering : Bool
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
    , headerTheme : Maybe JD.Value
    , clusterId : Maybe String
    , isRepresentative : Bool
    , clusterSize : Int
    }


type alias ClusterItem =
    { title : String
    , link : String
    , pubDate : Maybe Time.Posix
    , feedTitle : String
    , favicon : Maybe String
    , headerColor : Maybe String
    , headerTextColor : Maybe String
    , headerTheme : Maybe JD.Value
    , id : String
    }


type alias Cluster =
    { id : String
    , representative : ClusterItem
    , others : List ClusterItem
    , count : Int
    }


clusterItemsFromTimeline : List TimelineItem -> List Cluster
clusterItemsFromTimeline items =
    let
        sortedItems =
            List.sortWith
                (\a b ->
                    case ( a.pubDate, b.pubDate ) of
                        ( Nothing, Nothing ) ->
                            EQ

                        ( Nothing, _ ) ->
                            GT

                        ( _, Nothing ) ->
                            LT

                        ( Just pa, Just pb ) ->
                            compare (Time.posixToMillis pb) (Time.posixToMillis pa)
                )
                items

        grouped =
            List.foldl
                (\item acc ->
                    let
                        key =
                            Maybe.withDefault item.id item.clusterId

                        existing =
                            List.filter (\( k, _ ) -> k == key) acc
                    in
                    case existing of
                        [] ->
                            acc ++ [ ( key, [ item ] ) ]

                        _ ->
                            List.map
                                (\( k, v ) ->
                                    if k == key then
                                        ( k, v ++ [ item ] )

                                    else
                                        ( k, v )
                                )
                                acc
                )
                []
                sortedItems
    in
    List.map buildCluster grouped


{-| sortTimelineItems

    Defensive helper to ensure a list of TimelineItem is ordered newest -> oldest
    by pubDate. The UI uses this when merging pages to avoid ordering regressions.

-}
sortTimelineItems : List TimelineItem -> List TimelineItem
sortTimelineItems items =
    let
        comparePub a b =
            case ( a.pubDate, b.pubDate ) of
                ( Nothing, Nothing ) ->
                    EQ

                ( Nothing, _ ) ->
                    Basics.GT

                ( _, Nothing ) ->
                    Basics.LT

                ( Just pa, Just pb ) ->
                    -- Compare milliseconds descending (newest first)
                    Basics.compare (Time.posixToMillis pb) (Time.posixToMillis pa)
    in
    List.sortWith comparePub items


{-| sortFeedItems

    Ensure feed items are ordered newest -> oldest by pubDate. Used by the
    Home view when merging or displaying feed items inside feed cards.

-}
sortFeedItems : List FeedItem -> List FeedItem
sortFeedItems items =
    let
        comparePub a b =
            let
                ma =
                    case a.pubDate of
                        Nothing ->
                            -1

                        Just p ->
                            Time.posixToMillis p

                mb =
                    case b.pubDate of
                        Nothing ->
                            -1

                        Just p ->
                            Time.posixToMillis p

                tcmp =
                    Basics.compare mb ma
            in
            if tcmp /= EQ then
                tcmp

            else
                -- deterministic fallback using link
                Basics.compare b.link a.link

        sorted =
            List.sortWith comparePub items
    in
    sorted


buildCluster : ( String, List TimelineItem ) -> Cluster
buildCluster ( clusterId, clusterItems ) =
    let
        reps =
            List.filter .isRepresentative clusterItems

        othersFiltered =
            List.filter (not << .isRepresentative) clusterItems

        representative =
            case reps of
                rep :: _ ->
                    rep

                [] ->
                    case clusterItems of
                        first :: _ ->
                            first

                        [] ->
                            -- This case shouldn't happen with valid data
                            { id = ""
                            , title = "Unknown"
                            , link = ""
                            , pubDate = Nothing
                            , feedTitle = ""
                            , favicon = Nothing
                            , headerColor = Nothing
                            , headerTextColor = Nothing
                            , headerTheme = Nothing
                            , clusterId = Nothing
                            , isRepresentative = True
                            , clusterSize = 1
                            }

        -- Exclude representative from others to prevent duplication
        others =
            List.filter (\item -> item.id /= representative.id) othersFiltered
    in
    { id = clusterId
    , representative = toClusterItem representative
    , others = List.map toClusterItem others
    , count = List.length clusterItems
    }


toClusterItem : TimelineItem -> ClusterItem
toClusterItem item =
    { title = item.title
    , link = item.link
    , pubDate = item.pubDate
    , feedTitle = item.feedTitle
    , favicon = item.favicon
    , headerColor = item.headerColor
    , headerTextColor = item.headerTextColor
    , headerTheme = item.headerTheme
    , id = item.id
    }


feedDecoder : Decoder Feed
feedDecoder =
    field "tab" string
        |> JD.andThen
            (\tab ->
                field "url" string
                    |> JD.andThen
                        (\url ->
                            field "title" string
                                |> JD.andThen
                                    (\title ->
                                        field "display_link" string
                                            |> JD.andThen
                                                (\displayLink ->
                                                    field "site_link" string
                                                        |> JD.andThen
                                                            (\siteLink ->
                                                                field "favicon" (nullable string)
                                                                    |> JD.andThen
                                                                        (\favicon ->
                                                                            field "header_color" (nullable string)
                                                                                |> JD.andThen
                                                                                    (\headerColor ->
                                                                                        field "header_text_color" (nullable string)
                                                                                            |> JD.andThen
                                                                                                (\headerTextColor ->
                                                                                                    -- Parse optional header_theme_colors as a raw JSON value
                                                                                                    decodeNullableValueField "header_theme_colors"
                                                                                                        |> JD.andThen
                                                                                                            (\headerTheme ->
                                                                                                                field "items" (list feedItemDecoder)
                                                                                                                    |> JD.andThen
                                                                                                                        (\items ->
                                                                                                                            field "total_item_count" JD.int
                                                                                                                                |> JD.map
                                                                                                                                    (\totalItemCount ->
                                                                                                                                        { tab = tab
                                                                                                                                        , url = url
                                                                                                                                        , title = title
                                                                                                                                        , displayLink = displayLink
                                                                                                                                        , siteLink = siteLink
                                                                                                                                        , favicon = favicon
                                                                                                                                        , headerColor = headerColor
                                                                                                                                        , headerTextColor = headerTextColor
                                                                                                                                        , headerTheme = headerTheme
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
            )


feedItemDecoder : Decoder FeedItem
feedItemDecoder =
    JD.map3 FeedItem
        (field "title" string)
        (field "link" string)
        (field "pub_date" (nullable (JD.map Time.millisToPosix JD.int)))


decodeNullableValueField : String -> Decoder (Maybe JD.Value)
decodeNullableValueField name =
    JD.oneOf
        [ field name (nullable JD.value)
        , JD.succeed Nothing
        ]


timelineItemDecoder : Decoder TimelineItem
timelineItemDecoder =
    TimelineItem
        |> (\f -> field "id" string |> JD.map f)
        |> JD.andThen (\f -> field "title" string |> JD.map f)
        |> JD.andThen (\f -> field "link" string |> JD.map f)
        |> JD.andThen (\f -> field "pub_date" (nullable (JD.map Time.millisToPosix JD.int)) |> JD.map f)
        |> JD.andThen (\f -> field "feed_title" string |> JD.map f)
        |> JD.andThen (\f -> field "favicon" (nullable string) |> JD.map f)
        |> JD.andThen (\f -> field "header_color" (nullable string) |> JD.map f)
        |> JD.andThen (\f -> field "header_text_color" (nullable string) |> JD.map f)
        |> JD.andThen (\f -> decodeNullableValueField "header_theme_colors" |> JD.map f)
        |> JD.andThen (\f -> field "cluster_id" (nullable string) |> JD.map f)
        |> JD.andThen (\f -> field "is_representative" JD.bool |> JD.map f)
        |> JD.andThen (\f -> field "cluster_size" (JD.oneOf [ JD.int, JD.succeed 1 ]) |> JD.map f)


tabDecoder : Decoder Tab
tabDecoder =
    JD.map Tab (field "name" string)


feedsDecoder : Decoder FeedsResponse
feedsDecoder =
    FeedsResponse
        |> (\f -> field "tabs" (list tabDecoder) |> JD.map f)
        |> JD.andThen (\f -> field "active_tab" string |> JD.map f)
        |> JD.andThen (\f -> field "feeds" (list feedDecoder) |> JD.map f)
        |> JD.andThen (\f -> field "is_clustering" (JD.oneOf [ JD.bool, JD.succeed False ]) |> JD.map f)


timelineDecoder : Decoder TimelineResponse
timelineDecoder =
    TimelineResponse
        |> (\f -> field "items" (list timelineItemDecoder) |> JD.map f)
        |> JD.andThen (\f -> field "has_more" JD.bool |> JD.map f)
        |> JD.andThen (\f -> field "total_count" JD.int |> JD.map f)
        |> JD.andThen (\f -> field "is_clustering" (JD.oneOf [ JD.bool, JD.succeed False ]) |> JD.map f)


fetchTimeline : Int -> Int -> (Result Http.Error TimelineResponse -> msg) -> Cmd msg
fetchTimeline limit offset tagger =
    Http.get
        { url = "/api/timeline?limit=" ++ String.fromInt limit ++ "&offset=" ++ String.fromInt offset
        , expect = Http.expectJson tagger timelineDecoder
        }


fetchFeedMore : String -> Int -> Int -> (Result Http.Error Feed -> msg) -> Cmd msg
fetchFeedMore url limit offset tagger =
    Http.get
        { url = "/api/feed_more?url=" ++ Url.percentEncode url ++ "&limit=" ++ String.fromInt limit ++ "&offset=" ++ String.fromInt offset
        , expect = Http.expectJson tagger feedDecoder
        }


fetchFeeds : String -> (Result Http.Error FeedsResponse -> msg) -> Cmd msg
fetchFeeds tab tagger =
    Http.get
        { url = "/api/feeds?tab=" ++ Url.percentEncode tab
        , expect = Http.expectJson tagger feedsDecoder
        }

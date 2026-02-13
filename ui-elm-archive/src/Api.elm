module Api exposing (Cluster, ClusterItem, Feed, FeedItem, FeedsResponse, Tab, TimelineItem, TimelineResponse, clusterItemsFromTimeline, fetchFeedMore, fetchFeeds, fetchTimeline, sortFeedItems, sortTimelineItems)

import Http
import Json.Decode as JD exposing (Decoder, Value, field, list, nullable, string, succeed)
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
    , headerTheme : Maybe Decode.Value
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
    , headerTheme : Maybe Decode.Value
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
    , headerTheme : Maybe Decode.Value
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
    Decode.field "tab" string
        |> Decode.andThen
            (\tab ->
                Decode.field "url" string
                    |> Decode.andThen
                        (\url ->
                            Decode.field "title" string
                                |> Decode.andThen
                                    (\title ->
                                        Decode.field "display_link" string
                                            |> Decode.andThen
                                                (\displayLink ->
                                                    Decode.field "site_link" string
                                                        |> Decode.andThen
                                                            (\siteLink ->
                                                                Decode.field "favicon" (nullable string)
                                                                    |> Decode.andThen
                                                                        (\favicon ->
                                                                            Decode.field "header_color" (nullable string)
                                                                                |> Decode.andThen
                                                                                    (\headerColor ->
                                                                                        Decode.field "header_text_color" (nullable string)
                                                                                            |> Decode.andThen
                                                                                                (\headerTextColor ->
                                                                                                    -- Parse optional header_theme_colors as a raw JSON value
                                                                                                    decodeNullableValueField "header_theme_colors"
                                                                                                        |> Decode.andThen
                                                                                                            (\headerTheme ->
                                                                                                                Decode.field "items" (list feedItemDecoder)
                                                                                                                    |> Decode.andThen
                                                                                                                        (\items ->
                                                                                                                            Decode.field "total_item_count" Decode.int
                                                                                                                                |> Decode.andThen
                                                                                                                                    (\totalItemCount ->
                                                                                                                                        Decode.succeed
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
    Decode.map3 FeedItem
        (field "title" string)
        (field "link" string)
        (field "pub_date" (nullable (Decode.map Time.millisToPosix Decode.int)))


decodeNullableValueField : String -> Decoder (Maybe JD.Value)
decodeNullableValueField name =
    Decode.oneOf
        [ Decode.field name (nullable Decode.value)
        , Decode.succeed Nothing
        ]


timelineItemDecoder : Decoder TimelineItem
timelineItemDecoder =
    Decode.succeed TimelineItem
        |> Decode.andThen (\f -> Decode.field "id" string |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "title" string |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "link" string |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "pub_date" (nullable (Decode.map Time.millisToPosix Decode.int)) |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "feed_title" string |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "favicon" (nullable string) |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "header_color" (nullable string) |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "header_text_color" (nullable string) |> Decode.map f)
        |> Decode.andThen (\f -> decodeNullableValueField "header_theme_colors" |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "cluster_id" (nullable string) |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "is_representative" Decode.bool |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "cluster_size" (Decode.oneOf [ Decode.int, Decode.succeed 1 ]) |> Decode.map f)


tabDecoder : Decoder Tab
tabDecoder =
    Decode.map Tab (field "name" string)


feedsDecoder : Decoder FeedsResponse
feedsDecoder =
    Decode.succeed FeedsResponse
        |> Decode.andThen (\f -> Decode.field "tabs" (list tabDecoder) |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "active_tab" string |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "feeds" (list feedDecoder) |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "is_clustering" (Decode.oneOf [ Decode.bool, Decode.succeed False ]) |> Decode.map f)


timelineDecoder : Decoder TimelineResponse
timelineDecoder =
    TimelineResponse
        |> (\f -> Decode.field "items" (list timelineItemDecoder) |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "has_more" Decode.bool |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "total_count" Decode.int |> Decode.map f)
        |> Decode.andThen (\f -> Decode.field "is_clustering" (Decode.oneOf [ Decode.bool, Decode.succeed False ]) |> Decode.map f)


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

module Decoders exposing (..)

import Json.Decode exposing (Decoder, field, int, list, map, map2, map3, map4, map5, map6, map7, map8, maybe, nullable, string)
import Time exposing (Posix, millisToPosix)
import Types exposing (..)



-- Feed Decoder


feedDecoder : Decoder Feed
feedDecoder =
    map8 Feed
        (field "url" string)
        (field "title" string)
        (field "display_link" string)
        (field "site_link" string)
        (field "favicon" string)
        (field "favicon_data" string)
        (field "header_color" (nullable string))
        (field "items" (list feedItemDecoder))
        |> andThen
            (\url title displayLink siteLink favicon faviconData headerColor items ->
                map7 (\totalItemCount -> Feed url title displayLink siteLink favicon faviconData headerColor items totalItemCount)
                    (field "total_item_count" int)
            )



-- This is a workaround since elm 0.19 doesn't have Json.Decode.Pipeline
-- We need to use a different approach


feedDecoder : Decoder Feed
feedDecoder =
    let
        decodeFeed url title displayLink siteLink favicon faviconData headerColor items =
            map2 (\totalItemCount -> Feed url title displayLink siteLink favicon faviconData headerColor items)
                (field "total_item_count" int)
    in
    map7 decodeFeed
        (field "url" string)
        (field "title" string)
        (field "display_link" string)
        (field "site_link" string)
        (field "favicon" string)
        (field "favicon_data" string)
        (field "header_color" (nullable string))
        |> andThen
            (\url title displayLink siteLink favicon faviconData headerColor ->
                map2 (Feed url title displayLink siteLink favicon faviconData headerColor)
                    (field "items" (list feedItemDecoder))
                    |> andThen (\feed -> map (\totalItemCount -> { feed | totalItemCount = totalItemCount }) (field "total_item_count" int))
            )



-- Simplified Feed Decoder


feedDecoder : Decoder Feed
feedDecoder =
    field "url" string
        |> andThen
            (\url ->
                field "title" string
                    |> andThen
                        (\title ->
                            field "display_link" string
                                |> andThen
                                    (\displayLink ->
                                        field "site_link" string
                                            |> andThen
                                                (\siteLink ->
                                                    field "favicon" string
                                                        |> andThen
                                                            (\favicon ->
                                                                field "favicon_data" string
                                                                    |> andThen
                                                                        (\faviconData ->
                                                                            field "header_color" (nullable string)
                                                                                |> andThen
                                                                                    (\headerColor ->
                                                                                        field "items" (list feedItemDecoder)
                                                                                            |> andThen
                                                                                                (\items ->
                                                                                                    field "total_item_count" int
                                                                                                        |> andThen
                                                                                                            (\totalItemCount ->
                                                                                                                succeed (Feed url title displayLink siteLink favicon faviconData headerColor items totalItemCount)
                                                                                                            )
                                                                                                )
                                                                                    )
                                                                        )
                                                            )
                                                )
                                    )
                        )
            )



-- Feed Item Decoder


feedItemDecoder : Decoder FeedItem
feedItemDecoder =
    field "title" string
        |> andThen
            (\title ->
                field "link" string
                    |> andThen
                        (\link ->
                            field "version" (nullable string)
                                |> andThen
                                    (\version ->
                                        field "pub_date" (nullable (map millisToPosix int))
                                            |> andThen
                                                (\pubDate ->
                                                    succeed (FeedItem title link version pubDate)
                                                )
                                    )
                        )
            )



-- Tab Decoder


tabDecoder : Decoder Tab
tabDecoder =
    field "name" string
        |> andThen
            (\name ->
                succeed (Tab name)
            )



-- Timeline Item Decoder


timelineItemDecoder : Decoder TimelineItem
timelineItemDecoder =
    field "id" string
        |> andThen
            (\id ->
                field "title" string
                    |> andThen
                        (\title ->
                            field "link" string
                                |> andThen
                                    (\link ->
                                        field "pub_date" (nullable (map millisToPosix int))
                                            |> andThen
                                                (\pubDate ->
                                                    field "feed_title" string
                                                        |> andThen
                                                            (\feedTitle ->
                                                                field "cluster_id" (nullable string)
                                                                    |> andThen
                                                                        (\clusterId ->
                                                                            succeed (TimelineItem id title link pubDate feedTitle clusterId)
                                                                        )
                                                            )
                                                )
                                    )
                        )
            )



-- List of Feeds Decoder


feedsDecoder : Decoder (List Feed)
feedsDecoder =
    list feedDecoder



-- List of Timeline Items Decoder


timelineItemsDecoder : Decoder (List TimelineItem)
timelineItemsDecoder =
    list timelineItemDecoder



-- List of Tabs Decoder


tabsDecoder : Decoder (List Tab)
tabsDecoder =
    list tabDecoder



-- Version Decoder (returns timestamp as Posix)


versionDecoder : Decoder Posix
versionDecoder =
    map millisToPosix int



-- Error Decoder


errorDecoder : Decoder String
errorDecoder =
    field "error" string

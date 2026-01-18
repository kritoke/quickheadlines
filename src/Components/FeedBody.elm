module Components.FeedBody exposing (view)

import Element exposing (..)
import Element.Border as Border
import Element.Font as Font
import Html.Attributes
import Time exposing (Posix)
import Types exposing (FeedItem)


view : Posix -> List FeedItem -> Element msg
view now items =
    if List.isEmpty items then
        el [ padding 20, Font.color (rgb255 148 163 184) ] (text "No items available")

    else
        column
            [ width fill
            , height fill
            , spacing 0
            , paddingXY 12 8
            ]
            (List.map (feedItemView now) items)


feedItemView : Posix -> FeedItem -> Element msg
feedItemView now item =
    row
        [ width fill
        , spacing 8
        , paddingXY 0 6
        , htmlAttribute (Html.Attributes.style "list-style" "none")
        ]
        [ el
            [ Font.size 14
            , Font.color (rgb255 148 163 184)
            , width (px 6)
            , height (px 6)
            , Border.width 2
            , Border.color (rgb255 226 232 240)
            , Border.rounded 3
            , centerY
            ]
            Element.none
        , link
            [ width fill
            , Font.size 14
            , Font.color (rgb255 51 65 85)
            , htmlAttribute (Html.Attributes.style "word-wrap" "break-word")
            , htmlAttribute (Html.Attributes.style "line-height" "1.4")
            , mouseOver [ Font.color (rgb255 37 99 235) ]
            ]
            { url = item.link
            , label = text item.title
            }
        , relativeTime now item.pubDate
        ]


relativeTime : Posix -> Maybe Posix -> Element msg
relativeTime now pubDate =
    case pubDate of
        Just timestamp ->
            let
                nowMillis =
                    Time.posixToMillis now

                timestampMillis =
                    Time.posixToMillis timestamp

                diffMillis =
                    toFloat (nowMillis - timestampMillis)

                diffSeconds =
                    diffMillis / 1000

                diffMinutes =
                    diffSeconds / 60

                diffHours =
                    diffMinutes / 60

                diffDays =
                    diffHours / 24

                relativeStr =
                    if diffDays >= 1 then
                        String.fromInt (round diffDays) ++ "d"

                    else if diffHours >= 1 then
                        String.fromInt (round diffHours) ++ "h"

                    else if diffMinutes >= 1 then
                        String.fromInt (round diffMinutes) ++ "m"

                    else
                        "now"
            in
            el
                [ Font.size 14
                , Font.color (rgb255 148 163 184)
                , Font.light
                , htmlAttribute (Html.Attributes.style "white-space" "nowrap")
                ]
                (text relativeStr)

        Nothing ->
            Element.none

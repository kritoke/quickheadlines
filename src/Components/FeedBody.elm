module Components.FeedBody exposing (view)

import Html exposing (Html)
import Html.Attributes
import Time exposing (Posix)
import Types exposing (FeedItem)


view : Posix -> List FeedItem -> Html msg
view now items =
    if List.isEmpty items then
        Html.div
            [ Html.Attributes.style "padding" "1.25rem"
            , Html.Attributes.style "color" "#94a3b8"
            ]
            [ Html.text "No items available" ]

    else
        Html.div
            [ Html.Attributes.class "feed-body"
            , Html.Attributes.style "padding" "0.75rem"
            , Html.Attributes.style "flex" "1 1 auto"
            , Html.Attributes.style "min-height" "0"
            , Html.Attributes.style "width" "100%"
            , Html.Attributes.style "min-width" "0"
            ]
            (List.map (feedItemView now) items)


feedItemView : Posix -> FeedItem -> Html msg
feedItemView now item =
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "width" "100%"
        , Html.Attributes.style "gap" "0.5rem"
        , Html.Attributes.style "padding-top" "0.375rem"
        , Html.Attributes.style "padding-bottom" "0.375rem"
        , Html.Attributes.style "list-style" "none"
        ]
        [ Html.div
            [ Html.Attributes.style "width" "6px"
            , Html.Attributes.style "height" "6px"
            , Html.Attributes.style "border-width" "2px"
            , Html.Attributes.style "border-color" "#e2e8f0"
            , Html.Attributes.style "border-radius" "3px"
            , Html.Attributes.style "flex-shrink" "0"
            , Html.Attributes.style "align-self" "center"
            ]
            []
        , Html.a
            [ Html.Attributes.href item.link
            , Html.Attributes.style "width" "100%"
            , Html.Attributes.style "font-size" "0.875rem"
            , Html.Attributes.style "color" "#334155"
            , Html.Attributes.style "word-wrap" "break-word"
            , Html.Attributes.style "line-height" "1.4"
            ]
            [ Html.text item.title ]
        , relativeTime now item.pubDate
        ]


relativeTime : Posix -> Maybe Posix -> Html msg
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
            Html.span
                [ Html.Attributes.style "font-size" "0.875rem"
                , Html.Attributes.style "color" "#94a3b8"
                , Html.Attributes.style "font-weight" "300"
                , Html.Attributes.style "white-space" "nowrap"
                ]
                [ Html.text relativeStr ]

        Nothing ->
            Html.text ""
